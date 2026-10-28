import SwiftUI

/// Log a new custom activity, OR edit/delete an existing one when `editing`
/// is non-nil. The form fields pre-populate from the editing session.
/// Present inside a `NavigationStack`.
struct LogActivityView: View {
    @EnvironmentObject var units: UnitsService
    @Environment(\.dismiss) var dismiss

    /// If non-nil, the form is in edit mode for this session.
    var editing: WorkoutSession? = nil
    /// Optional default date for new activities (e.g. when logging from a past-day view).
    /// Defaults to "now" so the time-of-day field still feels natural.
    var forDate: Date? = nil

    @State private var name: String = ""
    @State private var category: Workout.Category = .cardio
    @State private var startedAt: Date = .now
    @State private var durationMinutes: Int = 30
    @State private var calories: Int = 220
    @State private var distance: String = ""
    @State private var notes: String = ""
    @State private var saving: Bool = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var distanceIsValid: Bool { distance.isEmpty || units.parseDistanceToKm(distance) != nil }
    private var canSave: Bool { !trimmedName.isEmpty && distanceIsValid && !saving }

    var body: some View {
        Form {
            Section("Activity") {
                FormTextField(label: "Name", text: $name, prompt: "e.g. Hike", capitalization: .words)
                Picker(selection: $category) {
                    ForEach(Workout.Category.allCases) { c in
                        Text(c.label).tag(c)
                    }
                } label: {
                    Label("Type", systemImage: category.icon)
                        .labelStyle(.titleOnly)
                }
            }

            Section("When") {
                DatePicker("Started", selection: $startedAt,
                           in: ...Date.now,
                           displayedComponents: [.date, .hourAndMinute])
            }

            Section {
                Stepper(value: $durationMinutes, in: 1...600, step: 5) {
                    LabeledContent("Duration", value: "\(durationMinutes) min")
                }
                .accessibilityValue("\(durationMinutes) min")
                Stepper(value: $calories, in: 0...3_000, step: 10) {
                    LabeledContent("Active energy", value: "\(calories) kcal")
                }
                .accessibilityValue("\(calories) kcal")
                FormTextField(label: "Distance", text: $distance, prompt: "Optional",
                              unit: units.distanceUnitLabel(), keyboard: .decimalPad)
            } header: {
                Text("How long & how hard")
            } footer: {
                if !distanceIsValid {
                    Text("Enter a distance greater than zero, or leave it empty.")
                        .foregroundStyle(VitalaColor.danger)
                }
            }

            Section {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text("Anything you want to remember.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if editing != nil {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete activity", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(editing == nil ? "Log activity" : "Edit activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(!canSave)
            }
        }
        .confirmationDialog("Delete this activity?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .keyboardDoneButton()
        .onAppear(perform: load)
    }

    // MARK: Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let s = editing {
            name = s.workoutName
            startedAt = s.startedAt
            durationMinutes = max(1, s.durationSeconds / 60)
            calories = s.caloriesBurned
            notes = s.notes ?? ""
            // Sessions logged before 1.0 didn't store a type; guess from the name.
            category = s.category ?? guessCategory(from: s.workoutName)
            if let km = s.distanceKm {
                distance = String(format: "%.2f", units.displayDistance(km: km))
            }
        } else if let d = forDate, !Calendar.current.isDateInToday(d) {
            // Anchor a backdated log to the selected day, but keep the
            // current time so the time-of-day picker isn't midnight.
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: .now)
            startedAt = cal.date(bySettingHour: comps.hour ?? 9, minute: comps.minute ?? 0, second: 0, of: d) ?? d
        }
    }

    private func save() async {
        saving = true
        let endedAt = startedAt.addingTimeInterval(Double(durationMinutes) * 60)
        let session = WorkoutSession(
            id: editing?.id ?? UUID().uuidString,
            workoutId: editing?.workoutId ?? "custom-\(UUID().uuidString.prefix(8))",
            workoutName: trimmedName,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationMinutes * 60,
            caloriesBurned: calories,
            notes: notes.isEmpty ? nil : notes,
            category: category,
            distanceKm: units.parseDistanceToKm(distance)
        )
        try? await DataStore.shared.logWorkout(session)
        Haptics.success()
        saving = false
        dismiss()
    }

    private func delete() async {
        guard let s = editing else { return }
        try? await DataStore.shared.deleteWorkout(s)
        dismiss()
    }

    // MARK: Helpers

    private func guessCategory(from name: String) -> Workout.Category {
        let lower = name.lowercased()
        if lower.contains("yoga") { return .yoga }
        if lower.contains("strength") || lower.contains("lift") { return .strength }
        if lower.contains("hiit") { return .hiit }
        if lower.contains("pilates") { return .pilates }
        if lower.contains("walk") { return .walking }
        if lower.contains("run") || lower.contains("jog") { return .running }
        if lower.contains("stretch") || lower.contains("mobility") { return .mobility }
        return .cardio
    }
}

#Preview {
    NavigationStack { LogActivityView() }
        .environmentObject(UnitsService())
}
