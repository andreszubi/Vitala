import SwiftUI

/// Turn iCloud sync on or off, see where it stands, and remove the copy
/// kept in iCloud.
struct CloudSyncView: View {
    @ObservedObject private var sync = CloudSync.shared
    @Environment(\.openURL) private var openURL
    @State private var confirmingDelete = false
    @State private var deleteFailed = false

    private var statusText: String {
        switch sync.status {
        case .off: "Off"
        case .waiting: "Waiting to sync"
        case .syncing: "Syncing…"
        case .upToDate(let date): "Up to date · \(date.formatted(date: .omitted, time: .shortened))"
        case .noAccount: "Not signed in to iCloud"
        case .restricted: "iCloud is restricted on this iPhone"
        case .accountNeedsAttention: "iCloud needs your attention"
        case .needsUpdate: "Update Vitala to keep syncing"
        case .failed: "Couldn't sync"
        }
    }

    /// What to do about the current status, when there is something to do.
    private var advice: String? {
        switch sync.status {
        case .noAccount: "Sign in to iCloud in the Settings app, then come back here."
        case .restricted: "Screen Time or a device profile is blocking iCloud for this iPhone."
        case .accountNeedsAttention: "You're signed in, but iCloud can't confirm your account on this iPhone right now. Open the Settings app and tap your name: if it asks you to sign in again or review your account, do that. Restarting the iPhone can also clear it. Vitala keeps trying, and nothing on this iPhone is lost in the meantime."
        case .needsUpdate: "A newer version of Vitala on another device saved your data. Update Vitala on this iPhone and it will carry on; nothing has been changed in the meantime."
        case .failed(let message): message
        default: nil
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Sync with iCloud", isOn: Binding(get: { sync.isOn }, set: { sync.setOn($0) }))
                    .accessibilityIdentifier("sync.toggle")
            } footer: {
                Text("Keeps your logs, journal, favourite foods, saved meals and the workouts you build the same on every iPhone signed in to your Apple Account. They are kept in your own private iCloud, which only you can read. Your profile, goals and photo stay on each iPhone.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if sync.isOn {
                Section {
                    LabeledContent("Status") {
                        HStack(spacing: 8) {
                            if sync.status == .syncing { ProgressView() }
                            Text(statusText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("sync.status")
                    if let advice {
                        Text(advice)
                            .font(VitalaFont.body(14))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    if let detail = sync.lastErrorDetail {
                        DisclosureGroup("Details for support") {
                            Text(detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(VitalaColor.textSecondary)
                                .textSelection(.enabled)
                        }
                        .font(VitalaFont.body(14))
                    }
                    if sync.status == .noAccount || sync.status == .accountNeedsAttention {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                    if sync.status != .noAccount {
                        Button("Sync now") { Task { await sync.syncNow() } }
                            .disabled(sync.status == .syncing)
                    }
                } footer: {
                    Text("Vitala syncs when you open it and a few seconds after you log something.")
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    Label("Delete the iCloud copy", systemImage: "icloud.slash")
                        .foregroundStyle(VitalaColor.danger)
                }
            } footer: {
                Text("Removes your data from iCloud and turns sync off on this iPhone. What is on this iPhone stays. Turn sync off on your other devices first, or they will save their copy again.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("iCloud sync")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete the iCloud copy?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete from iCloud", role: .destructive) {
                Task {
                    do { try await sync.deleteCloudCopy() } catch { deleteFailed = true }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data stays on this iPhone. Sync turns off here.")
        }
        .alert("Couldn't delete the iCloud copy", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Sync is off on this iPhone, but the copy is still in iCloud. Check your connection and that you're signed in to iCloud, then try again.")
        }
    }
}
