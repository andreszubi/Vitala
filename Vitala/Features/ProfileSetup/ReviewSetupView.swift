import SwiftUI

struct ReviewSetupView: View {
    @Binding var draft: UserProfile
    let onFinish: () -> Void
    @EnvironmentObject var units: UnitsService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You're all set")
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Here's what we'll start with — tweak any time in Goals.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                VStack(spacing: 10) {
                    Row(label: "Focus", value: draft.goals.primaryFocus.label, icon: draft.goals.primaryFocus.icon)
                    Row(label: "Daily steps", value: draft.goals.dailySteps.formatted(), icon: "figure.walk")
                    Row(label: "Move", value: "\(draft.goals.dailyActiveKcal) kcal", icon: "flame.fill")
                    Row(label: "Exercise", value: "\(draft.goals.dailyExerciseMinutes) min", icon: "figure.run")
                    Row(label: "Water", value: units.compactVolume(ml: draft.goals.dailyWaterMl), icon: "drop.fill")
                    Row(label: "Food energy", value: "\(draft.goals.dailyCalories.formatted()) kcal", icon: "fork.knife")
                    Row(label: "Sleep", value: "\(draft.goals.sleepHours.formatted(.number.precision(.fractionLength(1)))) hours", icon: "moon.stars.fill")
                }

                PrimaryButton(title: "Start using Vitala", icon: "sparkles", action: onFinish)
                    .padding(.top, VitalaSpacing.sm)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
    }

    private struct Row: View {
        let label: String
        let value: String
        let icon: String
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                Text(label).font(VitalaFont.body(15)).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(value).font(VitalaFont.bodyMedium(16)).foregroundStyle(VitalaColor.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .surfaceCard()
            .accessibilityElement(children: .combine)
        }
    }
}
