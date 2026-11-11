import SwiftUI

struct ActiveWorkoutView: View {
    let workout: Workout
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index: Int = 0
    @State private var startedAt: Date = .now
    /// Wall-clock bookkeeping so the timer stays right if the app is backgrounded.
    @State private var accumulated: TimeInterval = 0
    @State private var runningSince: Date? = .now
    @State private var exerciseAccumulated: TimeInterval = 0
    @State private var exerciseRunningSince: Date? = .now
    @State private var now: Date = .now
    @State private var confirmingEnd = false
    @State private var finished = false
    /// The workout on the Lock Screen and in the Dynamic Island.
    @State private var liveActivity = SessionLiveActivityController()

    private var current: Exercise { workout.exercises[index] }
    private var isLast: Bool { index == workout.exercises.count - 1 }
    private var isRunning: Bool { runningSince != nil }

    private var elapsed: Int {
        Int(accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0))
    }
    private var exerciseElapsed: Int {
        Int(exerciseAccumulated + (exerciseRunningSince.map { now.timeIntervalSince($0) } ?? 0))
    }
    /// Total seconds for a timed exercise (all sets), or nil for reps.
    private var exerciseDuration: Int? {
        current.seconds > 0 ? current.seconds * (current.sets ?? 1) : nil
    }
    private var plannedSeconds: Int { max(workout.durationMinutes * 60, 1) }
    private var earnedCalories: Int {
        Int((Double(workout.caloriesBurned) * min(1, Double(elapsed) / Double(plannedSeconds))).rounded())
    }

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: VitalaSpacing.lg) {
                        exerciseHeader
                        exerciseArt
                        Text(current.instructions)
                            .font(VitalaFont.body(16))
                            .foregroundStyle(VitalaColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, VitalaSpacing.md)
                        totalTimer
                    }
                    .padding(.horizontal, VitalaSpacing.lg)
                    .padding(.vertical, VitalaSpacing.md)
                }
                controls
                    .padding(.bottom, VitalaSpacing.lg)
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            liveActivity.start(kind: .workout, name: workout.name, symbol: workout.category.icon,
                               state: activityState, expectedEnd: activityExpectedEnd)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            liveActivity.end()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                tick()
            }
        }
        .confirmationDialog("End workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            if elapsed >= 60 {
                Button("Save workout") { save() }
            }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text(elapsed >= 60
                 ? "You've been moving for \(timeText(elapsed))."
                 : "Workouts shorter than a minute aren't saved.")
        }
    }

    // MARK: Sections

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "xmark", label: "End workout") { confirmingEnd = true }
            Spacer()
            Text(workout.name)
                .font(VitalaFont.bodyMedium(15))
                .foregroundStyle(VitalaColor.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, VitalaSpacing.md)
        .padding(.top, VitalaSpacing.xs)
    }

    private var exerciseHeader: some View {
        VStack(spacing: VitalaSpacing.xs) {
            Text("Exercise \(index + 1) of \(workout.exercises.count)")
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
            Text(current.name)
                .font(VitalaFont.title(28))
                .foregroundStyle(VitalaColor.textPrimary)
                .multilineTextAlignment(.center)
            Text(prescription)
                .font(VitalaFont.bodyMedium(15))
                .foregroundStyle(VitalaColor.primary)
        }
        .accessibilityElement(children: .combine)
    }

    private var exerciseArt: some View {
        ZStack {
            Circle().fill(VitalaColor.primary.opacity(0.10))
            if let duration = exerciseDuration {
                Circle()
                    .trim(from: 0, to: min(1, Double(exerciseElapsed) / Double(duration)))
                    .stroke(VitalaColor.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(5)
                    .animation(reduceMotion ? nil : .linear(duration: 0.5), value: exerciseElapsed)
                VStack(spacing: 2) {
                    ExerciseDemoView(exercise: current, playing: isRunning)
                        .frame(width: 150, height: 124)
                    Text(timeText(max(0, duration - exerciseElapsed)))
                        .numeralFont(30)
                        .foregroundStyle(VitalaColor.textPrimary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time left in this exercise")
                .accessibilityValue(spokenTime(max(0, duration - exerciseElapsed)))
                .accessibilityAddTraits(.updatesFrequently)
            } else {
                ExerciseDemoView(exercise: current, playing: isRunning)
                    .frame(width: 168, height: 168)
            }
        }
        .frame(width: 240, height: 240)
    }

    private var totalTimer: some View {
        VStack(spacing: 2) {
            Text(timeText(elapsed))
                .numeralFont(44)
                .foregroundStyle(VitalaColor.textPrimary)
            Text("total · \(earnedCalories) kcal")
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout time")
        .accessibilityValue("\(spokenTime(elapsed)), about \(earnedCalories) kilocalories")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            GlassIconButton(systemName: "backward.fill", label: "Previous exercise", size: 60) { move(by: -1) }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.4 : 1)
            GlassIconButton(systemName: isRunning ? "pause.fill" : "play.fill",
                            label: isRunning ? "Pause" : "Resume",
                            size: 84, prominent: true, tint: VitalaColor.primaryFill) { togglePause() }
            GlassIconButton(systemName: isLast ? "checkmark" : "forward.fill",
                            label: isLast ? "Finish workout" : "Next exercise", size: 60) {
                // Too short to save: say so rather than closing without a word.
                if !isLast { move(by: 1) } else if elapsed >= 60 { save() } else { confirmingEnd = true }
            }
        }
        .glassGroup(spacing: 20)
    }

    // MARK: Logic

    private var prescription: String { current.prescription ?? "At your own pace" }

    /// What the Live Activity shows right now.
    private var activityState: SessionActivityAttributes.ContentState {
        let t = Date.now
        let total = accumulated + (runningSince.map { t.timeIntervalSince($0) } ?? 0)
        let inExercise = exerciseAccumulated + (exerciseRunningSince.map { t.timeIntervalSince($0) } ?? 0)
        return .workout(exercise: current.name, index: index, count: workout.exercises.count,
                        prescription: prescription, elapsed: total,
                        stepRemaining: exerciseDuration.map { Double($0) - inExercise },
                        isRunning: isRunning, now: t)
    }

    /// Well past when the workout should be over: after this the system
    /// marks the activity as out of date.
    private var activityExpectedEnd: Date {
        Date.now.addingTimeInterval(Double(plannedSeconds) * 2 + 1_800)
    }

    private func tick() {
        guard !finished else { return }
        now = .now
        // Not behind the "End workout?" question: Discard must stay possible.
        if let duration = exerciseDuration, isRunning, !confirmingEnd, exerciseElapsed >= duration {
            Haptics.success()
            if isLast { save() } else { move(by: 1) }
        }
    }

    private func togglePause() {
        let t = Date.now
        if let since = runningSince {
            accumulated += t.timeIntervalSince(since)
            runningSince = nil
            if let s = exerciseRunningSince { exerciseAccumulated += t.timeIntervalSince(s) }
            exerciseRunningSince = nil
        } else {
            runningSince = t
            exerciseRunningSince = t
        }
        now = t
        liveActivity.update(activityState, expectedEnd: activityExpectedEnd)
    }

    private func move(by delta: Int) {
        let target = index + delta
        guard workout.exercises.indices.contains(target) else { return }
        index = target
        exerciseAccumulated = 0
        exerciseRunningSince = isRunning ? .now : nil
        now = .now
        AccessibilityNotification.Announcement("Now: \(current.name), \(prescription)").post()
        liveActivity.update(activityState, expectedEnd: activityExpectedEnd)
    }

    private func save() {
        guard !finished else { return }
        finished = true
        let endedAt = Date.now
        let seconds = elapsed
        guard seconds >= 60 else { dismiss(); return }
        let session = WorkoutSession(
            workoutId: workout.id,
            workoutName: workout.name,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: seconds,
            caloriesBurned: earnedCalories,
            category: workout.category
        )
        Task {
            try? await DataStore.shared.logWorkout(session)
            Haptics.success()
        }
        liveActivity.end(showing: .finished("Workout saved", seconds: seconds))
        dismiss()
    }

    private func timeText(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func spokenTime(_ secs: Int) -> String {
        Duration.seconds(secs).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }
}
