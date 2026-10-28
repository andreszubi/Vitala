import SwiftUI

@main
struct VitalaApp: App {
    @StateObject private var profileStore = ProfileStore()
    @StateObject private var appState = AppState()
    @StateObject private var health = HealthKitService.shared
    @StateObject private var notifications = NotificationService.shared
    @StateObject private var units = UnitsService()
    @StateObject private var themeService = ThemeService()

    init() {
        #if DEBUG
        DebugLaunchOptions.apply()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .environmentObject(appState)
                .environmentObject(health)
                .environmentObject(notifications)
                .environmentObject(units)
                .environmentObject(themeService)
                .preferredColorScheme(themeService.theme.colorScheme)
                .tint(VitalaColor.primary)
        }
    }
}
