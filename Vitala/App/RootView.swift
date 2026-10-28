import SwiftUI

struct RootView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var appState: AppState

    @State private var didSplash = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var slide: AnyTransition { reduceMotion ? .opacity : .move(edge: .trailing) }

    var body: some View {
        ZStack {
            VitalaColor.background.ignoresSafeArea()

            switch appState.route {
            case .splash:
                SplashView(onFinish: { Task { await resolve() } })
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(slide)
            case .profileSetup:
                ProfileSetupRootView()
                    .transition(slide)
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: appState.route)
        .task(id: profileStore.profile?.id) {
            // Re-route whenever the profile is created or erased.
            if didSplash {
                appState.resolveRoute(profile: profileStore.profile)
            }
        }
    }

    private func resolve() async {
        didSplash = true
        appState.resolveRoute(profile: profileStore.profile)
    }
}
