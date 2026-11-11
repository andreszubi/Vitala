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
        // Starts following changes if the user has iCloud sync on.
        _ = CloudSync.shared
        // A session the app was closed in the middle of may have left its
        // Live Activity on the Lock Screen.
        SessionLiveActivityController.endLeftovers()
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
