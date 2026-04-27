import SwiftUI

struct ProfileSetupRootView: View {
    @State private var step: Int = 0
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var notifications: NotificationService

    @State private var draft: UserProfile = .init(id: "", email: "", displayName: "")

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                StepProgressBar(step: step, total: 4)
                    .padding(.horizontal, VitalaSpacing.lg)
                    .padding(.top, VitalaSpacing.md)

                Group {
                    switch step {
                    case 0: PersonalInfoView(draft: $draft, onNext: { step += 1 })
                    case 1: GoalsFocusView(draft: $draft, onNext: { step += 1 })
                    case 2: PermissionsView(onNext: { step += 1 })
                    default: ReviewSetupView(draft: $draft, onFinish: finish)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear {
            if let p = auth.profile { draft = p }
        }
    }

    private func finish() {
        Task {
            try? await auth.saveProfile(draft)
            appState.completeProfileSetup()
        }
    }
}

private struct StepProgressBar: View {
    let step: Int
    let total: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? VitalaColor.primary : VitalaColor.muted.opacity(0.25))
                    .frame(height: 6)
            }
        }
    }
}
