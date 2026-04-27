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
                    .padding(.top, VitalaSpacing.md)

                GoalSlider(label: "Steps", value: $draft.goals.dailySteps,
                           range: 2_000...20_000, step: 500, format: { "\($0.formatted())" })
                GoalSlider(label: "Water (\(units.volumeUnitLabel()))",
                           value: $draft.goals.dailyWaterMl,
                           range: 1_000...4_000, step: 100,
                           format: { units.formatVolume(ml: Double($0)) })
                GoalSlider(label: "Calories", value: $draft.goals.dailyCalories,
                           range: 1_200...3_500, step: 50, format: { "\($0)" })
                GoalSliderDouble(label: "Sleep (hours)", value: $draft.goals.sleepHours,
                                 range: 5...10, step: 0.5, format: { String(format: "%.1f", $0) })

                Spacer().frame(height: VitalaSpacing.md)

                PrimaryButton(title: "Continue", icon: "arrow.right", action: onNext)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
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
                ZStack {
                    Circle()
                        .fill(isSelected ? VitalaColor.primary.opacity(0.15) : VitalaColor.surface)
                        .frame(width: 44, height: 44)
                    Image(systemName: focus.icon)
                        .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textPrimary)
                }
                Text(focus.label).font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.muted.opacity(0.5))
                    .font(.system(size: 22))
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(VitalaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(isSelected ? VitalaColor.primary.opacity(0.5) : Color.black.opacity(0.05),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GoalSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let format: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(format(value)).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.primary)
            }
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
            .tint(VitalaColor.primary)
        }
    }
}

private struct GoalSliderDouble: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(format(value)).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.primary)
            }
            Slider(value: $value, in: range, step: step).tint(VitalaColor.primary)
        }
    }
}
