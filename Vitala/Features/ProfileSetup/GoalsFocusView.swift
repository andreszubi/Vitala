import SwiftUI

struct GoalsFocusView: View {
    @Binding var draft: UserProfile
    let onNext: () -> Void

    @EnvironmentObject var units: UnitsService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What feels important right now?")
                        .font(VitalaFont.title(26))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a focus. You can change it any time.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(WellnessGoals.Focus.allCases) { focus in
                        FocusRow(focus: focus, isSelected: draft.goals.primaryFocus == focus) {
                            draft.goals.primaryFocus = focus
                        }
                    }
                }

                Text("Your daily targets")
                    .font(VitalaFont.headline(18))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, VitalaSpacing.sm)

                GoalTargetsEditor(goals: $draft.goals, suggestedCalories: draft.suggestedDailyCalories())

                PrimaryButton(title: "Continue", icon: "arrow.right", action: onNext)
                    .padding(.top, VitalaSpacing.sm)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
    }
}

/// Sliders for every daily target. Shared by profile setup and Goals.
struct GoalTargetsEditor: View {
    @Binding var goals: WellnessGoals
    var suggestedCalories: Int? = nil

    @EnvironmentObject var units: UnitsService

    var body: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.md) {
            GoalSlider(label: "Steps", value: $goals.dailySteps,
                       range: 2_000...25_000, step: 500, format: { $0.formatted() })
            GoalSlider(label: "Move (active energy)", value: $goals.dailyActiveKcal,
                       range: 150...1_200, step: 10, format: { "\($0) kcal" })
            GoalSlider(label: "Exercise", value: $goals.dailyExerciseMinutes,
                       range: 10...120, step: 5, format: { "\($0) min" })
            GoalSlider(label: "Workouts per week", value: $goals.weeklyWorkouts,
                       range: 1...14, step: 1, format: { "\($0)" })
            GoalSlider(label: "Water", value: $goals.dailyWaterMl,
                       range: 1_000...4_500, step: 100,
                       format: { units.compactVolume(ml: $0) })
            VStack(alignment: .leading, spacing: 6) {
                GoalSlider(label: "Food energy", value: $goals.dailyCalories,
                           range: 1_200...4_000, step: 50, format: { "\($0.formatted()) kcal" })
                if let suggestedCalories, suggestedCalories != goals.dailyCalories {
                    Button("Use suggested \(suggestedCalories.formatted()) kcal") {
                        goals.dailyCalories = suggestedCalories
                    }
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.primary)
                    .frame(minHeight: 44)
                    .accessibilityHint("Based on your height, weight, age and activity level")
                }
            }
            GoalSlider(label: "Mindful minutes", value: $goals.dailyMindfulMinutes,
                       range: 2...60, step: 1, format: { "\($0) min" })
            GoalSliderDouble(label: "Sleep", value: $goals.sleepHours,
                             range: 5...10, step: 0.5,
                             format: { "\($0.formatted(.number.precision(.fractionLength(1)))) hours" })
        }
    }
}

private struct FocusRow: View {
    let focus: WellnessGoals.Focus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VitalaSpacing.sm) {
                Image(systemName: focus.icon)
                    .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(isSelected ? VitalaColor.primary.opacity(0.15) : VitalaColor.background))
                    .accessibilityHidden(true)
                Text(focus.label).font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.muted)
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10).padding(.horizontal, 14)
            .background(VitalaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(isSelected ? VitalaColor.primary : VitalaColor.hairline,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GoalSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(format(value)).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.primary)
            }
            .accessibilityHidden(true)
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step)) {
                Text(label)
            }
            .tint(VitalaColor.primary)
            .accessibilityValue(format(value))
        }
    }
}

struct GoalSliderDouble: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(format(value)).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.primary)
            }
            .accessibilityHidden(true)
            Slider(value: $value, in: range, step: step) { Text(label) }
                .tint(VitalaColor.primary)
                .accessibilityValue(format(value))
        }
    }
}
