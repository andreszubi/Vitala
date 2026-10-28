import SwiftUI

struct ProfileSetupRootView: View {
    @State private var step: Int = 0
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var draft: UserProfile = .init(id: "", displayName: "")
    private let totalSteps = 4

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, VitalaSpacing.md)
                    .padding(.top, VitalaSpacing.xs)

                Group {
                    switch step {
                    case 0: PersonalInfoView(draft: $draft, onNext: next)
                    case 1: GoalsFocusView(draft: $draft, onNext: next)
                    case 2: PermissionsView(onNext: next)
                    default: ReviewSetupView(draft: $draft, onFinish: finish)
                    }
                }
                .frame(maxHeight: .infinity)
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing),
                                                                  removal: .move(edge: .leading)))
            }
        }
        .onAppear {
            if let p = profileStore.profile { draft = p }
        }
    }

    private var header: some View {
        HStack(spacing: VitalaSpacing.sm) {
            GlassIconButton(systemName: "chevron.left", label: "Back") {
                withAnimation(reduceMotion ? nil : .default) { step = max(0, step - 1) }
            }
            .opacity(step > 0 ? 1 : 0)
            .disabled(step == 0)
            .accessibilityHidden(step == 0)
            .accessibilityLabel("Back")

            StepProgressBar(step: step, total: totalSteps)

            Color.clear.frame(width: 44, height: 44)
        }
    }

    private func next() {
        withAnimation(reduceMotion ? nil : .default) { step += 1 }
    }

    private func finish() {
        Task {
            try? await profileStore.saveProfile(draft)
            Haptics.success()
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
        .padding(.vertical, 19)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step + 1) of \(total)")
    }
}
