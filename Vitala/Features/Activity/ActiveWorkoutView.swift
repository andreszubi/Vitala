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
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
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
            Button { confirmingEnd = true } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VitalaColor.surface))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .accessibilityLabel("End workout")
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
                VStack(spacing: 4) {
                    Image(systemName: current.icon)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(VitalaColor.primary)
                    Text(timeText(max(0, duration - exerciseElapsed)))
                        .numeralFont(32)
                        .foregroundStyle(VitalaColor.textPrimary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time left in this exercise")
                .accessibilityValue(spokenTime(max(0, duration - exerciseElapsed)))
                .accessibilityAddTraits(.updatesFrequently)
            } else {
                Image(systemName: current.icon)
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(VitalaColor.primary)
                    .accessibilityHidden(true)
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
            Button { move(by: -1) } label: {
                Image(systemName: "backward.fill")
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(VitalaColor.surface))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .disabled(index == 0)
            .opacity(index == 0 ? 0.4 : 1)
            .accessibilityLabel("Previous exercise")

            Button { togglePause() } label: {
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(VitalaColor.primaryGradient))
                    .foregroundStyle(.white)
                    .shadow(color: VitalaColor.primaryFill.opacity(0.35), radius: 12, y: 6)
            }
            .accessibilityLabel(isRunning ? "Pause" : "Resume")

            Button { isLast ? save() : move(by: 1) } label: {
                Image(systemName: isLast ? "checkmark" : "forward.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(VitalaColor.surface))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .accessibilityLabel(isLast ? "Finish workout" : "Next exercise")
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Logic

    private var prescription: String {
        if current.seconds > 0 {
            let time = current.seconds >= 60 ? "\(current.seconds / 60) min" : "\(current.seconds) sec"
            if let sets = current.sets, sets > 1 { return "\(sets) × \(time)" }
            return time
        }
        if let sets = current.sets, let reps = current.reps { return "\(sets) × \(reps) reps" }
        if let reps = current.reps { return "\(reps) reps" }
        return "At your own pace"
    }

    private func tick() {
        guard !finished else { return }
        now = .now
        if let duration = exerciseDuration, isRunning, exerciseElapsed >= duration {
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
    }

    private func move(by delta: Int) {
        let target = index + delta
        guard workout.exercises.indices.contains(target) else { return }
        index = target
        exerciseAccumulated = 0
        exerciseRunningSince = isRunning ? .now : nil
        now = .now
        AccessibilityNotification.Announcement("Now: \(current.name), \(prescription)").post()
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
        dismiss()
    }

    private func timeText(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    private func spokenTime(_ secs: Int) -> String {
        Duration.seconds(secs).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }
}
