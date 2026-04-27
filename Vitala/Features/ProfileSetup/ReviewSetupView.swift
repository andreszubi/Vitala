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
                    Text("Here's what we'll start with — tweak any time.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                VStack(spacing: 10) {
                    Row(label: "Focus", value: draft.goals.primaryFocus.label, icon: draft.goals.primaryFocus.icon)
                    Row(label: "Daily steps", value: "\(draft.goals.dailySteps.formatted())", icon: "figure.walk")
                    Row(label: "Daily water", value: units.formatVolume(ml: Double(draft.goals.dailyWaterMl)), icon: "drop.fill")
                    Row(label: "Daily calories", value: "\(draft.goals.dailyCalories) kcal", icon: "flame.fill")
                    Row(label: "Sleep target", value: String(format: "%.1f h", draft.goals.sleepHours), icon: "moon.stars.fill")
                }

                Spacer().frame(height: VitalaSpacing.md)

                PrimaryButton(title: "Start using Vitala", icon: "sparkles", action: onFinish)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
    }

    private struct Row: View {
        let label: String
        let value: String
        let icon: String
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(VitalaColor.primary).frame(width: 26)
                Text(label).font(VitalaFont.body(15)).foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text(value).font(VitalaFont.bodyMedium(16)).foregroundStyle(VitalaColor.textPrimary)
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(VitalaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
        }
    }
}
