import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var notifications: NotificationService
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect what helps")
                        .font(VitalaFont.title(28))
                    Text("Both are optional and can be changed in Settings.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                PermissionCard(
                    icon: "heart.text.square.fill",
                    tint: VitalaColor.coral,
                    title: "Apple Health",
                    message: "Sync steps, workouts, sleep, and heart rate with Apple Health.",
                    isOn: health.isAuthorized,
                    actionTitle: "Connect"
                ) {
                    Task { await health.requestAuthorization() }
                }

                PermissionCard(
                    icon: "bell.badge.fill",
                    tint: VitalaColor.primary,
                    title: "Gentle reminders",
                    message: "We'll send a few mindful nudges — hydration, stretches, wind-down.",
                    isOn: notifications.authorizationStatus == .authorized,
                    actionTitle: "Allow"
                ) {
                    Task { _ = await notifications.request() }
                }

                Spacer().frame(height: VitalaSpacing.md)

                PrimaryButton(title: "Continue", icon: "arrow.right", action: onNext)
                GhostButton(title: "Skip for now", action: onNext)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .task {
            await notifications.refreshStatus()
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let isOn: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: VitalaSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(tint.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon).foregroundStyle(tint).font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(message).font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
            if isOn {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(VitalaColor.success).font(.system(size: 22))
            } else {
                Button(actionTitle, action: action)
                    .font(VitalaFont.bodyMedium(14))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(tint.opacity(0.15))
                    .foregroundStyle(tint)
                    .clipShape(Capsule())
            }
        }
        .padding(VitalaSpacing.md)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}
