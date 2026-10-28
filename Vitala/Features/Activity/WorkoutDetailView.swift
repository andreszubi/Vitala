import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    @State private var startSession = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                cover
                stats
                description
                exercises
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .bottomActionBar {
            PrimaryButton(title: "Start session", icon: "play.fill") {
                startSession = true
            }
        }
        .fullScreenCover(isPresented: $startSession) {
            ActiveWorkoutView(workout: workout)
        }
    }

    private var cover: some View {
        let tint = Color(hex: workout.coverTint)
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [tint, tint.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: workout.imageSystemName)
                .font(.system(size: 88, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(VitalaSpacing.md)
                .accessibilityHidden(true)
            // Scrim keeps the white title readable on light covers.
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.category.label.uppercased())
                    .font(VitalaFont.caption(11))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.35)))
                    .foregroundStyle(.white)
                Text(workout.name)
                    .font(VitalaFont.title(26))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(VitalaSpacing.md)
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.lg, style: .continuous))
        .padding(.top, VitalaSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            stat(icon: "clock", value: "\(workout.durationMinutes) min", label: "Duration")
            stat(icon: "flame.fill", value: "\(workout.caloriesBurned) kcal", label: "Estimated energy")
            stat(icon: "chart.bar", value: workout.difficulty.label, label: "Level")
        }
    }

    private func stat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(VitalaColor.primary).accessibilityHidden(true)
            Text(value).font(VitalaFont.bodyMedium(14)).foregroundStyle(VitalaColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .surfaceCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "About this session")
            Text("Move at your own pace. If something feels off, ease back. Vitala believes in showing up, not pushing through.")
                .font(VitalaFont.body(15))
                .foregroundStyle(VitalaColor.textSecondary)
        }
    }

    private var exercises: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Exercises", trailing: "\(workout.exercises.count)")
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
            Text("\(index)")
                .font(VitalaFont.bodyMedium(15))
                .frame(width: 30, height: 30)
                .background(Circle().fill(VitalaColor.primary.opacity(0.1)))
                .foregroundStyle(VitalaColor.primary)
            Image(systemName: exercise.icon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.1)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(detailText).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        if exercise.seconds > 0 {
            let time = exercise.seconds >= 60 ? "\(exercise.seconds / 60) min" : "\(exercise.seconds) sec"
            if let sets = exercise.sets, sets > 1 { return "\(sets) × \(time)" }
            return time
        }
        if let sets = exercise.sets, let reps = exercise.reps { return "\(sets) × \(reps) reps" }
        return exercise.instructions
    }
}
