import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var appState: AppState

    @State private var didSplash = false

    var body: some View {
        ZStack {
            VitalaColor.background.ignoresSafeArea()

            switch appState.route {
            case .splash:
                SplashView(onFinish: { Task { await resolve() } })
                    .transition(.opacity)
            case .onboarding:
                OnboardingView()
                    .transition(.move(edge: .trailing))
            case .auth:
                AuthRootView()
                    .transition(.opacity)
            case .profileSetup:
                ProfileSetupRootView()
                    .transition(.move(edge: .trailing))
            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: appState.route)
        .task(id: auth.profile?.id) {
            // Whenever auth state lands, recompute route.
            if didSplash {
                appState.resolveRoute(authProfile: auth.profile)
            }
        }
    }

    private func resolve() async {
        didSplash = true
        // Tiny delay so the splash isn't jarring.
        try? await Task.sleep(nanoseconds: 100_000_000)
        appState.resolveRoute(authProfile: auth.profile)
    }
}
