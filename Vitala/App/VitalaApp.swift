import SwiftUI

@main
struct VitalaApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var appState = AppState()
    @StateObject private var health = HealthKitService.shared
    @StateObject private var notifications = NotificationService.shared
    @StateObject private var units = UnitsService()
    @StateObject private var themeService = ThemeService()

    init() {
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor.label]
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
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
