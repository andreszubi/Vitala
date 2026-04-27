import SwiftUI
import HealthKit

/// Log a new custom activity, OR edit/delete an existing one when `editing`
/// is non-nil. The form fields pre-populate from the editing session.
struct LogActivityView: View {
    @EnvironmentObject var health: HealthKitService
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Name (e.g. Pickleball, Hike, Cycling)", text: $name)
                        .textInputAutocapitalization(.words)
                    Picker("Type", selection: $category) {
                        ForEach(Workout.Category.allCases) { c in
                            Label(c.label.capitalized, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section("When") {
                    DatePicker("Started", selection: $startedAt,
                               in: ...Date.now,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Section("How long & how hard") {
                    Stepper("Duration: \(durationMinutes) min",
                            value: $durationMinutes, in: 1...600, step: 5)
                    Stepper("Calories: \(calories) kcal",
                            value: $calories, in: 0...3_000, step: 10)
                    HStack {
                        Text("Distance (optional)")
                        Spacer()
                        TextField(units.distanceUnitLabel(), text: $distance)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                    }
                }

                Section("Notes") {
                    TextField("Anything you want to remember", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            HStack { ProgressView(); Text("Saving…") }
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(editing == nil ? "Save activity" : "Save changes").bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                    .foregroundStyle(VitalaColor.primary)

                    if editing != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete activity")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log activity" : "Edit activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let s = editing {
                    name = s.workoutName
                    startedAt = s.startedAt
                    durationMinutes = max(1, s.durationSeconds / 60)
                    calories = s.caloriesBurned
                    notes = s.notes ?? ""
                    // Best guess on category from name (we don't store it on the session).
                    category = guessCategory(from: s.workoutName)
                } else if let d = forDate, !Calendar.current.isDateInToday(d) {
                    // Anchor a backdated log to the selected day, but keep the
                    // current time so the time-of-day picker isn't midnight.
                    let cal = Calendar.current
                    let comps = cal.dateComponents([.hour, .minute], from: .now)
                    var anchor = cal.startOfDay(for: d)
                    anchor = cal.date(byAdding: .hour, value: comps.hour ?? 9, to: anchor) ?? anchor
                    anchor = cal.date(byAdding: .minute, value: comps.minute ?? 0, to: anchor) ?? anchor
                    startedAt = min(anchor, .now)
                }
            }
        }
    }

    // MARK: Actions

    private func save() async {
        saving = true
        let endedAt = startedAt.addingTimeInterval(Double(durationMinutes) * 60)
        let session = WorkoutSession(
            id: editing?.id ?? UUID().uuidString,
            workoutId: editing?.workoutId ?? "custom-\(UUID().uuidString.prefix(8))",
            workoutName: name.trimmingCharacters(in: .whitespaces),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: durationMinutes * 60,
            caloriesBurned: calories,
            notes: notes.isEmpty ? nil : notes
        )
        try? await FirestoreService.shared.logWorkout(session)

        // Best-effort HealthKit write — fire-and-forget.
        let activity = hkActivity(for: category)
        let kcal = Double(calories)
        Task.detached { [health] in
            try? await health.logWorkout(activity: activity,
                                         start: startedAt,
                                         end: endedAt,
                                         kcal: kcal)
        }
        saving = false
        dismiss()
    }

    private func delete() async {
        guard let s = editing else { return }
        try? await FirestoreService.shared.deleteWorkout(s)
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

    private func hkActivity(for category: Workout.Category) -> HKWorkoutActivityType {
        switch category {
        case .yoga: return .yoga
        case .strength: return .functionalStrengthTraining
        case .cardio: return .mixedCardio
        case .hiit: return .highIntensityIntervalTraining
        case .pilates: return .pilates
        case .mobility: return .flexibility
        case .walking: return .walking
        case .running: return .running
        }
    }
}

#Preview {
    LogActivityView()
        .environmentObject(HealthKitService.shared)
        .environmentObject(UnitsService())
}
