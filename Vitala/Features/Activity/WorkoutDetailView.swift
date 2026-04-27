import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var startSession = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                cover
                stats
                description
                exercises
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            PrimaryButton(title: "Start session", icon: "play.fill") {
                startSession = true
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.lg)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $startSession) {
            ActiveWorkoutView(workout: workout)
        }
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(hex: workout.coverTint),
                                              Color(hex: workout.coverTint).opacity(0.6)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 220)
            Image(systemName: workout.imageSystemName)
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.category.label.uppercased())
                    .font(VitalaFont.caption(11))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.white.opacity(0.25))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                Text(workout.name).font(VitalaFont.title(26)).foregroundStyle(.white)
            }
            .padding(VitalaSpacing.md)
        }
        .padding(.top, VitalaSpacing.md)
    }

    private var stats: some View {
        HStack(spacing: 12) {
            stat(icon: "clock", value: "\(workout.durationMinutes) min")
            stat(icon: "flame.fill", value: "\(workout.caloriesBurned) kcal")
            stat(icon: "chart.bar", value: workout.difficulty.label.capitalized)
        }
    }

    private func stat(icon: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(VitalaColor.primary)
            Text(value).font(VitalaFont.bodyMedium(14))
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About this session").font(VitalaFont.headline(18))
            Text("Move at your own pace. If something feels off, ease back. Vitala believes in showing up, not pushing through.")
                .font(VitalaFont.body(15))
                .foregroundStyle(VitalaColor.textSecondary)
        }
    }

    private var exercises: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Exercises (\(workout.exercises.count))")
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                ExerciseRow(index: idx + 1, exercise: ex)
            }
        }
    }
}

private struct ExerciseRow: View {
    let index: Int
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)").font(VitalaFont.bodyMedium(15))
                .frame(width: 28, height: 28)
                .background(VitalaColor.primary.opacity(0.1))
                .foregroundStyle(VitalaColor.primary)
                .clipShape(Circle())
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(VitalaColor.sage.opacity(0.18)).frame(width: 44, height: 44)
                Image(systemName: exercise.icon).foregroundStyle(VitalaColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(VitalaFont.bodyMedium(15))
                Text(detailText).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
        }
        .padding(10)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
    }

    private var detailText: String {
        if let sets = exercise.sets, let reps = exercise.reps {
            return "\(sets) × \(reps) reps"
        } else if exercise.seconds > 0 {
            return "\(exercise.seconds) sec"
        }
        return ""
    }
}
