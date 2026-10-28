import SwiftUI

/// Five native tabs. Using the system `TabView` gives VoiceOver, Large
/// Content Viewer and (on iOS 26+) Liquid Glass for free. Profile and
/// Settings live behind the avatar on Today.
struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            DashboardView()
                .tabItem { tabLabel(.home) }
                .tag(AppState.MainTab.home)
            NavigationStack { WorkoutsListView() }
                .tabItem { tabLabel(.activity) }
                .tag(AppState.MainTab.activity)
            NavigationStack { NutritionView() }
                .tabItem { tabLabel(.nutrition) }
                .tag(AppState.MainTab.nutrition)
            NavigationStack { MindfulnessView() }
                .tabItem { tabLabel(.mindfulness) }
                .tag(AppState.MainTab.mindfulness)
            NavigationStack { SleepView() }
                .tabItem { tabLabel(.sleep) }
                .tag(AppState.MainTab.sleep)
        }
        .tint(VitalaColor.primary)
        .onChange(of: appState.selectedTab) { _, _ in Haptics.selection() }
    }

    private func tabLabel(_ tab: AppState.MainTab) -> some View {
        Label(tab.label, systemImage: tab.icon)
    }
}
