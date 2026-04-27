import SwiftUI

/// Edit a logged mindful session — change title, minutes, or completion time,
/// or delete it outright.
struct EditMindfulnessSheet: View {
    let entry: LoggedMindfulness
    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var minutes: Int = 0
    @State private var completedAt: Date = .now
    @State private var saving: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var didLoad: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                }
                Section("Length") {
                    Stepper("Minutes: \(minutes)", value: $minutes, in: 1...180, step: 1)
                }
                Section("When") {
                    DatePicker("Completed",
                               selection: $completedAt,
                               in: ...Date.now,
                               displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            HStack { ProgressView(); Text("Saving…") }
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save changes").bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(saving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .foregroundStyle(VitalaColor.primary)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete session")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
    }

    private func save() async {
        saving = true; defer { saving = false }
        var updated = entry
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.minutes = minutes
        updated.completedAt = completedAt
        try? await FirestoreService.shared.logMindfulness(updated)
        dismiss()
    }

    private func delete() async {
        try? await FirestoreService.shared.deleteMindfulness(entry)
        dismiss()
    }
}
