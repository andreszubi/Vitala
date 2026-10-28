import SwiftUI

/// Edit a logged mindful session — change title, minutes, or completion time,
/// or delete it outright. Present inside a `NavigationStack`.
struct EditMindfulnessSheet: View {
    let entry: LoggedMindfulness
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var minutes: Int = 0
    @State private var completedAt: Date = .now
    @State private var saving: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var didLoad: Bool = false

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        Form {
            Section("Session") {
                TextField("Title", text: $title)
                    .textInputAutocapitalization(.words)
            }
            Section("Length") {
                Stepper(value: $minutes, in: 1...180) {
                    LabeledContent("Minutes", value: "\(minutes)")
                }
            }
            Section("When") {
                DatePicker("Completed",
                           selection: $completedAt,
                           in: ...Date.now,
                           displayedComponents: [.date, .hourAndMinute])
            }
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete session", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle("Edit session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving || trimmedTitle.isEmpty)
            }
        }
        .confirmationDialog("Delete this session?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            title = entry.title
            minutes = entry.minutes
            completedAt = entry.completedAt
        }
    }

    private func save() async {
        saving = true; defer { saving = false }
        var updated = entry
        updated.title = trimmedTitle
        updated.minutes = minutes
        updated.completedAt = completedAt
        try? await DataStore.shared.logMindfulness(updated)
        Haptics.success()
        dismiss()
    }

    private func delete() async {
        try? await DataStore.shared.deleteMindfulness(entry)
        dismiss()
    }
}
