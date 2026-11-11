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

                GoalsEditor(profile: $draft)

                PrimaryButton(title: "Continue", icon: "arrow.right", action: onNext)
                    .padding(.top, VitalaSpacing.sm)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
    }
}

/// The daily targets for a profile: either worked out by Vitala from the
/// profile and focus, updating as they change, or set by hand. Shared by
/// profile setup and Goals.
struct GoalsEditor: View {
    @Binding var profile: UserProfile

    @EnvironmentObject var units: UnitsService
    @State private var targetWeight = ""
    @State private var didLoad = false

    private var plan: GoalPlan? { profile.plan() }
    private var aimsAtAWeight: Bool {
        profile.goals.primaryFocus == .loseWeight || profile.goals.primaryFocus == .buildMuscle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.md) {
            Toggle(isOn: $profile.goals.followsPlan) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Work out my targets for me")
                        .font(VitalaFont.bodyMedium(16))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text("From your focus, sex, age, height, weight and activity level.")
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(VitalaColor.primaryFill)
            .accessibilityIdentifier("goals.followsPlan")

            if profile.goals.followsPlan, let plan {
                if aimsAtAWeight {
                    FormTextField(label: "Target weight", text: $targetWeight, prompt: "Optional",
                                  unit: units.weightUnitLabel(), keyboard: .decimalPad)
                        .padding(.vertical, 4)
                }
                GoalPlanSummary(plan: plan)
            } else {
                if profile.goals.followsPlan {
                    Label("Add your height, weight and birthday in your profile and Vitala will work these out. Until then, set them here.",
                          systemImage: "info.circle")
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                GoalTargetsEditor(goals: $profile.goals, suggestedCalories: plan?.calories)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let kg = profile.goals.weightTargetKg {
                targetWeight = units.displayWeight(kg: kg).formatted(.number.precision(.fractionLength(0...1)))
            }
            profile = profile.followingPlan()
        }
        .onChange(of: targetWeight) { _, text in
            let kg = units.parseWeightToKg(text)
            profile.goals.weightTargetKg = kg.flatMap { UserProfile.weightRangeKg.contains($0) ? $0 : nil }
            profile = profile.followingPlan()
        }
        .onChange(of: profile.goals.primaryFocus) { _, _ in profile = profile.followingPlan() }
        .onChange(of: profile.goals.followsPlan) { _, _ in profile = profile.followingPlan() }
    }
}

/// The plan's targets, read-only, each with what it is based on.
struct GoalPlanSummary: View {
    let plan: GoalPlan
    @EnvironmentObject var units: UnitsService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("fork.knife", "Food energy", "\(plan.calories.formatted()) kcal",
                "You use about \(plan.maintenanceCalories.formatted()) kcal a day. "
                    + plan.paceText { units.formatWeight(kg: $0, decimals: 1) })
            row("fish.fill", "Protein", "\(plan.proteinG) g", nil)
            row("flame.fill", "Move", "\(plan.activeKcal) kcal", "Active energy, scaled to your weight.")
            row("figure.walk", "Steps", plan.steps.formatted(), "A daily distance, counted in your stride.")
            row("figure.run", "Exercise", "\(plan.exerciseMinutes) min",
                "\(plan.weeklyWorkouts) workouts a week.")
            row("drop.fill", "Water", units.compactVolume(ml: plan.waterMl), nil)
            row("moon.stars.fill", "Sleep",
                "\(plan.sleepHours.formatted(.number.precision(.fractionLength(0...1)))) hours", nil)
            row("leaf.fill", "Mindful", "\(plan.mindfulMinutes) min", nil)
            Text("These follow your profile: change your weight, focus or activity level and they update. They are general estimates for healthy adults, not medical advice. Talk to a healthcare professional before changing how you eat or train, especially if you are pregnant, under 18 or managing a condition.")
                .font(VitalaFont.caption(12))
                .foregroundStyle(VitalaColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func row(_ icon: String, _ label: String, _ value: String, _ detail: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Spacer(minLength: 8)
                    Text(value)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.primary)
                }
                if let detail {
                    Text(detail)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Sliders for every daily target, for people who set their own.
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
                    .buttonStyle(TapTargetButtonStyle())
                    .accessibilityHint("Based on your height, weight, age and activity level")
                }
            }
            GoalSlider(label: "Protein", value: $goals.dailyProteinG,
                       range: 40...220, step: 5, format: { "\($0) g" })
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
