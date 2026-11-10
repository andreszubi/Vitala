import SwiftUI

/// Build a workout from the exercise library, or edit one built earlier.
/// Present inside a `NavigationStack`.
struct WorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileStore: ProfileStore
    @ObservedObject private var store = DataStore.shared

    private let existing: Workout?
    /// Called after the workout being edited is deleted.
    var onDelete: (() -> Void)? = nil

    @State private var name: String
    @State private var category: Workout.Category
    @State private var difficulty: Workout.Difficulty
    @State private var exercises: [Exercise]
    @State private var confirmingDelete = false
    @State private var confirmingDiscard = false

    init(editing workout: Workout? = nil, onDelete: (() -> Void)? = nil) {
        existing = workout
        self.onDelete = onDelete
        _name = State(initialValue: workout?.name ?? "")
        _category = State(initialValue: workout?.category ?? .strength)
        _difficulty = State(initialValue: workout?.difficulty ?? .beginner)
        _exercises = State(initialValue: workout?.exercises ?? [])
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && !exercises.isEmpty }
    private var minutes: Int { Workout.estimatedMinutes(for: exercises) }
    private var calories: Int {
        Workout.estimatedCalories(category: category, minutes: minutes, weightKg: profileStore.profile?.weightKg)
    }
    private var hasChanges: Bool {
        guard let existing else { return !trimmedName.isEmpty || !exercises.isEmpty }
        return trimmedName != existing.name || category != existing.category
            || difficulty != existing.difficulty || exercises != existing.exercises
    }

    var body: some View {
        Form {
            Section {
                FormTextField(label: "Name", text: $name, prompt: "Morning circuit")
                Picker("Type", selection: $category) {
                    ForEach(Workout.Category.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                Picker("Level", selection: $difficulty) {
                    ForEach(Workout.Difficulty.allCases) { d in
                        Text(d.label).tag(d)
                    }
                }
            }

            Section {
                ForEach($exercises) { $exercise in
                    NavigationLink {
                        ExerciseSettingsView(exercise: $exercise)
                    } label: {
                        BuilderExerciseRow(exercise: exercise)
                    }
                }
                .onDelete { exercises.remove(atOffsets: $0) }
                .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }

                NavigationLink {
                    ExercisePickerView(chosen: $exercises)
                } label: {
                    Label("Add exercises", systemImage: "plus.circle.fill")
                        .foregroundStyle(VitalaColor.primary)
                }
                .accessibilityIdentifier("builder.addExercises")
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    if exercises.count > 1 { EditButton().font(.footnote) }
                }
            } footer: {
                Text(exercises.isEmpty
                     ? "Add at least one exercise. Tap one afterwards to set its time or reps."
                     : "About \(minutes) min and \(calories) kcal. Tap an exercise to set its time or reps; swipe to remove it.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete workout", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle(existing == nil ? "Build a workout" : "Edit workout")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled(hasChanges)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges { confirmingDiscard = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog("Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let existing { store.deleteCustomWorkout(existing) }
                dismiss()
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sessions you already logged with it stay in your history.")
        }
        .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }

    private func save() {
        guard canSave else { return }
        store.saveCustomWorkout(.custom(id: existing?.id, name: trimmedName, category: category,
                                        difficulty: difficulty, exercises: exercises,
                                        weightKg: profileStore.profile?.weightKg))
        Haptics.success()
        dismiss()
    }
}

/// One exercise in the workout being built.
private struct BuilderExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseDemoView(exercise: exercise, still: true)
                .padding(4)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.1)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(exercise.prescription ?? "At your own pace")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Sets its time or reps")
    }
}

/// How one exercise is done in this workout: for a time or for a number of
/// reps, and how many sets.
struct ExerciseSettingsView: View {
    @Binding var exercise: Exercise

    private enum Measure: String, CaseIterable, Identifiable {
        case time, reps
        var id: String { rawValue }
        var label: String { self == .time ? "Time" : "Reps" }
    }

    private var measure: Binding<Measure> {
        Binding(get: { exercise.seconds > 0 ? .time : .reps },
                set: { new in
                    switch new {
                    case .time:
                        exercise.seconds = 30
                        exercise.reps = nil
                    case .reps:
                        exercise.seconds = 0
                        exercise.reps = 10
                    }
                })
    }

    private var sets: Binding<Int> {
        Binding(get: { max(1, exercise.sets ?? 1) },
                set: { exercise.sets = $0 > 1 ? $0 : nil })
    }

    private var reps: Binding<Int> {
        Binding(get: { exercise.reps ?? 10 }, set: { exercise.reps = $0 })
    }

    private var timeLabel: String {
        exercise.seconds >= 60 && exercise.seconds % 60 == 0
            ? "\(exercise.seconds / 60) min"
            : exercise.seconds > 60 ? "\(exercise.seconds / 60) min \(exercise.seconds % 60) sec" : "\(exercise.seconds) sec"
    }

    var body: some View {
        Form {
            Section {
                ExerciseDemoView(exercise: exercise)
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .padding(.vertical, 8)
                    .listRowBackground(VitalaColor.primary.opacity(0.08))
                Text(exercise.instructions)
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section {
                Picker("Measure by", selection: measure) {
                    ForEach(Measure.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                if exercise.seconds > 0 {
                    Stepper(value: $exercise.seconds, in: 10...3600, step: exercise.seconds >= 120 ? 30 : 5) {
                        LabeledContent("Time", value: timeLabel)
                    }
                } else {
                    Stepper(value: reps, in: 1...100) {
                        LabeledContent("Reps", value: "\(reps.wrappedValue)")
                    }
                }
                Stepper(value: sets, in: 1...10) {
                    LabeledContent("Sets", value: "\(sets.wrappedValue)")
                }
            } footer: {
                Text(exercise.seconds > 0
                     ? "The workout counts the time down and moves on by itself."
                     : "The workout waits for you to tap Next when you've done your reps.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The exercise library, grouped by kind. Tapping adds an exercise; it can
/// be added more than once.
struct ExercisePickerView: View {
    @Binding var chosen: [Exercise]

    private func count(of entry: ExerciseLibrary.Entry) -> Int {
        chosen.filter { $0.name == entry.exercise.name }.count
    }

    var body: some View {
        List {
            ForEach(ExerciseLibrary.categories) { category in
                Section(category.label) {
                    ForEach(ExerciseLibrary.all.filter { $0.category == category }) { entry in
                        Button {
                            var exercise = entry.exercise
                            exercise.id = UUID().uuidString
                            chosen.append(exercise)
                            Haptics.selection()
                            AccessibilityNotification.Announcement("Added \(exercise.name)").post()
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Adds it to the workout")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Add exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ entry: ExerciseLibrary.Entry) -> some View {
        let added = count(of: entry)
        return HStack(spacing: 12) {
            ExerciseDemoView(exercise: entry.exercise, still: true)
                .padding(4)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.1)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exercise.name)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(entry.exercise.prescription ?? entry.exercise.instructions)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 8)
            if added > 0 {
                Text("\(added)")
                    .font(VitalaFont.caption(13))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(VitalaColor.primaryFill))
                    .accessibilityLabel("Added \(added) \(added == 1 ? "time" : "times")")
            }
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(VitalaColor.primary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
