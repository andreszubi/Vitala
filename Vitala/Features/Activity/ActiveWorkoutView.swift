import SwiftUI
import HealthKit

struct ActiveWorkoutView: View {
    let workout: Workout
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var health: HealthKitService

    @State private var index: Int = 0
    @State private var elapsed: Int = 0
    @State private var isRunning = true
    @State private var startedAt: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var current: Exercise { workout.exercises[index] }

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            VStack(spacing: VitalaSpacing.lg) {
                topBar

                VStack(spacing: VitalaSpacing.sm) {
                    Text("Exercise \(index + 1) of \(workout.exercises.count)")
                        .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                    Text(current.name).font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle().fill(VitalaColor.primary.opacity(0.12))
                        .frame(width: 260, height: 260)
                    Image(systemName: current.icon)
                        .font(.system(size: 110, weight: .bold))
                        .foregroundStyle(VitalaColor.primary)
                }

                Text(current.instructions)
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VitalaSpacing.lg)

                Text(timerText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VitalaColor.primary)

                HStack(spacing: 12) {
                    Button {
                        prev()
                    } label: {
                        Image(systemName: "backward.fill")
                            .frame(width: 56, height: 56)
                            .background(VitalaColor.surface)
                            .clipShape(Circle())
                            .foregroundStyle(VitalaColor.textPrimary)
                    }

                    Button {
                        isRunning.toggle()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 28))
                            .frame(width: 80, height: 80)
                            .background(VitalaColor.primary)
                            .clipShape(Circle())
                            .foregroundStyle(.white)
                            .shadow(color: VitalaColor.primary.opacity(0.4), radius: 12, y: 6)
                    }

                    Button {
                        next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .frame(width: 56, height: 56)
                            .background(VitalaColor.surface)
                            .clipShape(Circle())
                            .foregroundStyle(VitalaColor.textPrimary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.lg)
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            elapsed += 1
        }
    }

    private var topBar: some View {
        HStack {
            Button { finish() } label: {
                Image(systemName: "xmark")
                    .frame(width: 36, height: 36)
                    .background(VitalaColor.surface)
                    .clipShape(Circle())
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            Spacer()
            Text(workout.name).font(VitalaFont.bodyMedium(15))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var timerText: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func next() {
        if index < workout.exercises.count - 1 {
            index += 1
        } else {
            finish()
        }
    }

    private func prev() {
        if index > 0 { index -= 1 }
    }

    private func finish() {
        let endedAt = Date.now
        // Persist + try to write to HealthKit
        let session = WorkoutSession(
            workoutId: workout.id,
            workoutName: workout.name,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSeconds: elapsed,
            caloriesBurned: workout.caloriesBurned
        )
        let activity = hkActivity()
        let kcal = Double(workout.caloriesBurned)
        Task {
            try? await FirestoreService.shared.logWorkout(session)
        }
        // Fire-and-forget HK write so dismiss isn't blocked if HK hangs.
        Task.detached { [health] in
            try? await health.logWorkout(activity: activity,
                                         start: startedAt, end: endedAt,
                                         kcal: kcal)
        }
        dismiss()
    }

    private func hkActivity() -> HKWorkoutActivityType {
        switch workout.category {
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
