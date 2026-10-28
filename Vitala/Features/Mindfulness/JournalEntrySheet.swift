import SwiftUI

/// Write or edit a journal entry: a mood and whatever's on your mind.
/// Present inside a `NavigationStack`.
struct JournalEntrySheet: View {
    @Environment(\.dismiss) var dismiss

    private let existing: JournalEntry?
    private let session: LoggedMindfulness?

    @State private var mood: JournalEntry.Mood
    @State private var text: String
    @State private var date: Date
    @State private var saving = false
    @State private var confirmingDelete = false
    @FocusState private var writing: Bool

    /// A new entry, optionally following a session just completed.
    init(after session: LoggedMindfulness? = nil, on day: Date = .now) {
        existing = nil
        self.session = session
        _mood = State(initialValue: session == nil ? .okay : .calm)
        _text = State(initialValue: "")
        _date = State(initialValue: Self.time(on: day))
    }

    init(editing entry: JournalEntry) {
        existing = entry
        session = nil
        _mood = State(initialValue: entry.mood)
        _text = State(initialValue: entry.text)
        _date = State(initialValue: entry.date)
    }

    private var sessionTitle: String? { session?.title ?? existing?.sessionTitle }

    var body: some View {
        Form {
            if let sessionTitle {
                Section {
                    Label("After \(sessionTitle)", systemImage: "leaf.fill")
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }
            Section("Mood") {
                Picker("How are you feeling?", selection: $mood) {
                    ForEach(JournalEntry.Mood.allCases) { m in
                        Label(m.label, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Entry") {
                TextField("Entry", text: $text, prompt: Text(prompt), axis: .vertical)
                    .lineLimit(8...)
                    .focused($writing)
                    .accessibilityLabel("Journal entry")
            }
            Section("When") {
                DatePicker("Date", selection: $date, in: ...Date.now,
                           displayedComponents: [.date, .hourAndMinute])
            }
            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete entry", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle(existing == nil ? "New entry" : "Journal entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(saving)
            }
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { if existing == nil { writing = true } }
    }

    private var prompt: String {
        session == nil ? "What's on your mind?" : "How do you feel after that?"
    }

    private func save() async {
        saving = true; defer { saving = false }
        var entry = existing ?? JournalEntry(date: date, mood: mood, text: "",
                                             sessionId: session?.id, sessionTitle: session?.title)
        entry.date = date
        entry.mood = mood
        entry.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await DataStore.shared.saveJournal(entry)
        Haptics.success()
        dismiss()
    }

    private func delete() async {
        guard let existing else { return }
        try? await DataStore.shared.deleteJournal(existing)
        dismiss()
    }

    /// Now, when writing for today; otherwise midday on the chosen day.
    private static func time(on day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return .now }
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }
}
