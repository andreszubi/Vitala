import SwiftUI

/// The account signed in on this iPhone: who it is, signing out, and
/// deleting it.
struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profileStore: ProfileStore
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var notifications: NotificationService
    @ObservedObject private var sync = CloudSync.shared

    @State private var confirmingSignOut = false
    @State private var confirmingDelete = false
    @State private var deleting = false
    @State private var failure: String?
    @State private var appleSignIn = AppleSignIn()

    var body: some View {
        Form {
            if let account = auth.account {
                Section {
                    LabeledContent("Signed in with", value: account.provider.label)
                    if let email = account.email {
                        LabeledContent("Email", value: email)
                    }
                } footer: {
                    Text(auth.mode == .development
                         ? "Development build: this account exists only on this device."
                         : "Your account holds only your sign-in. Your logs stay on this iPhone, or in your own iCloud if sync is on.")
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            Section {
                Button("Sign out") { confirmingSignOut = true }
                    .accessibilityIdentifier("account.signOut")
            } footer: {
                Text("Your data stays on this iPhone for when you sign back in.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    HStack {
                        Label("Delete account", systemImage: "person.crop.circle.badge.xmark")
                            .foregroundStyle(VitalaColor.danger)
                        if deleting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(deleting)
                .accessibilityIdentifier("account.delete")
            } footer: {
                Text("Deletes your Vitala account and erases your profile and every log from this iPhone\(sync.isOn ? ", from iCloud and from your other devices that sync" : ""). This can't be undone. Anything already saved to Apple Health stays there.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign out") { auth.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to use Vitala.")
        }
        .confirmationDialog("Delete your account?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete account and data", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(auth.account?.provider == .apple
                 ? "Apple will ask you to confirm it's you. Then your account and everything Vitala stored are deleted for good."
                 : "Your account and everything Vitala stored are deleted for good.")
        }
        .alert("Couldn't delete your account", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            if failure == AuthError.needsRecentSignIn.errorDescription {
                Button("Sign out") { auth.signOut() }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
    }

    private func deleteAccount() {
        deleting = true
        Task {
            defer { deleting = false }
            do {
                // An account made with Apple is confirmed by Apple first.
                let apple = auth.account?.provider == .apple && auth.mode == .live
                    ? try await appleSignIn.confirm() : nil
                try await auth.deleteAccount(confirmedBy: apple)
                // The account is gone; so is what it kept here.
                DataStore.shared.eraseAll(everywhere: sync.isOn)
                if sync.isOn { await sync.syncNow() }
                notifications.reset()
                profileStore.erase()
                appState.resetAfterErase(isSignedIn: auth.isSignedIn)
            } catch let error as AuthError {
                if let message = error.errorDescription { failure = message }
            } catch {
                failure = "Something went wrong. Try again."
            }
        }
    }
}
