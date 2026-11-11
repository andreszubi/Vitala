import SwiftUI
import Combine

/// Drives top-level navigation between Splash → Onboarding → Profile setup → Main app.
@MainActor
final class AppState: ObservableObject {
    enum Route: Equatable {
        case splash
        /// Nobody is signed in: Vitala needs an account.
        case signIn
        case onboarding
        case profileSetup
        case main
    }

    @Published var route: Route = .splash
    @Published var hasSeenOnboarding: Bool = UserDefaults.standard.bool(forKey: "vitala.hasSeenOnboarding") {
        didSet { UserDefaults.standard.set(hasSeenOnboarding, forKey: "vitala.hasSeenOnboarding") }
    }
    @Published var hasCompletedProfile: Bool = UserDefaults.standard.bool(forKey: "vitala.hasCompletedProfile") {
        didSet { UserDefaults.standard.set(hasCompletedProfile, forKey: "vitala.hasCompletedProfile") }
    }

    @Published var selectedTab: MainTab = .home

    enum MainTab: String, CaseIterable, Identifiable {
        case home, activity, nutrition, mindfulness, sleep
        var id: String { rawValue }
        var label: String {
            switch self {
            case .home: "Today"
            case .activity: "Activity"
            case .nutrition: "Nutrition"
            case .mindfulness: "Mindful"
            case .sleep: "Sleep"
            }
        }
        var icon: String {
            switch self {
            case .home: "sun.max.fill"
            case .activity: "figure.run"
            case .nutrition: "fork.knife"
            case .mindfulness: "leaf.fill"
            case .sleep: "moon.stars.fill"
            }
        }
    }

    func resolveRoute(profile: UserProfile?, isSignedIn: Bool) {
        if !isSignedIn {
            route = .signIn
        } else if !hasSeenOnboarding || profile == nil {
            route = .onboarding
        } else if !hasCompletedProfile {
            route = .profileSetup
        } else {
            route = .main
        }
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        route = .profileSetup
    }

    func completeProfileSetup() {
        hasCompletedProfile = true
        route = .main
    }

    /// Returns to a first-launch state after the user erases their data:
    /// setting up again if they are still signed in, signing in if not.
    func resetAfterErase(isSignedIn: Bool) {
        hasCompletedProfile = false
        hasSeenOnboarding = false
        selectedTab = .home
        route = isSignedIn ? .onboarding : .signIn
    }
}
