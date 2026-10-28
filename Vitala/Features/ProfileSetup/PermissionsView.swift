import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var notifications: NotificationService
    @Environment(\.openURL) private var openURL
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect what helps")
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Both are optional and can be changed later in Settings.")
                        .font(VitalaFont.body(15))
                        .foregroundStyle(VitalaColor.textSecondary)
                }

                if health.isAvailable {
                    PermissionCard(
                        icon: "heart.text.square.fill",
                        tint: VitalaColor.coralText,
                        title: "Apple Health",
                        message: "Show steps, heart rate and sleep from Health, and save what you log here back to Health.",
                        state: health.isAuthorized ? .granted : .available,
                        actionTitle: "Connect"
                    ) {
                        Task { await health.requestAuthorization() }
                    }
                }

                PermissionCard(
                    icon: "bell.badge.fill",
                    tint: VitalaColor.primary,
                    title: "Gentle reminders",
                    message: "A few mindful nudges a day — hydration, a stretch, winding down. You choose which and when.",
                    state: notificationState,
                    actionTitle: notifications.authorizationStatus == .denied ? "Open Settings" : "Allow"
                ) {
                    if notifications.authorizationStatus == .denied {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } else {
                        Task { _ = await notifications.request() }
                    }
                }

                PrimaryButton(title: "Continue", icon: "arrow.right", action: onNext)
                    .padding(.top, VitalaSpacing.sm)
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.top, VitalaSpacing.md)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .task {
            await notifications.refreshStatus()
        }
    }

    private var notificationState: PermissionCard.State {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        default: .available
        }
    }
}

private struct PermissionCard: View {
    enum State { case available, granted }

    let icon: String
    let tint: Color
    let title: String
    let message: String
    let state: State
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack(alignment: .top, spacing: VitalaSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.14)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(VitalaFont.bodyMedium(16))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text(message).font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
            }

            if state == .granted {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.success)
                    .frame(minHeight: 44)
            } else {
                Button(action: action) {
                    Text(actionTitle)
                        .font(VitalaFont.bodyMedium(15))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(VitalaColor.primary.opacity(0.12)))
                        .foregroundStyle(VitalaColor.primary)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("\(actionTitle), \(title)")
            }
        }
        .vitalaCard()
    }
}
