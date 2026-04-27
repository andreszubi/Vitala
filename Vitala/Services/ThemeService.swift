import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Match system"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light:  "sun.max.fill"
        case .dark:   "moon.fill"
        }
    }
    /// nil means "follow the OS" (no override).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }
}

@MainActor
final class ThemeService: ObservableObject {
    @AppStorage("vitala.theme") private var stored: String = AppTheme.system.rawValue

    var theme: AppTheme {
        get { AppTheme(rawValue: stored) ?? .system }
        set {
            stored = newValue.rawValue
            objectWillChange.send()
        }
    }
}
