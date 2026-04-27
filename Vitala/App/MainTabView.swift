import SwiftUI

/// Custom tab container — bypasses TabView entirely so iOS doesn't auto-
/// collapse our six tabs into a "More" overflow. All tab views are kept
/// alive via opacity gating so state (scroll position, NavigationStack
/// path, etc.) is preserved when switching back to a tab.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            tabContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VitalaTabBar(selection: $appState.selectedTab)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .tint(VitalaColor.primary)
    }

    private var tabContent: some View {
        ZStack {
            tab(.home) { DashboardView() }
            tab(.activity) { NavigationStack { WorkoutsListView() } }
            tab(.nutrition) { NavigationStack { NutritionView() } }
            tab(.mindfulness) { NavigationStack { MindfulnessView() } }
            tab(.sleep) { NavigationStack { SleepView() } }
            tab(.profile) { NavigationStack { ProfileView() } }
        }
    }

    /// Wraps a tab's content with opacity-based visibility so all tabs stay
    /// alive (preserving state) but only the active one receives input.
    @ViewBuilder
    private func tab<V: View>(_ key: AppState.MainTab,
                              @ViewBuilder content: () -> V) -> some View {
        let isActive = appState.selectedTab == key
        content()
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            // Defer accessibility too so VoiceOver doesn't read hidden tabs.
            .accessibilityHidden(!isActive)
    }
}
