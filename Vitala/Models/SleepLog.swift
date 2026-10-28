import Foundation

struct SleepEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var bedTime: Date
    var wakeTime: Date
    var quality: Quality
    var notes: String?
    /// Time actually asleep, for nights read from Apple Health. Logged
    /// nights count everything from bedtime to wake-up.
    var asleepHours: Double? = nil

    var hours: Double {
        if let asleepHours { return asleepHours }
        let secs = wakeTime.timeIntervalSince(bedTime)
        return max(0, secs / 3600)
    }

    /// Recorded by another app and read from Apple Health; not editable here.
    var isFromHealth: Bool { id.hasPrefix("health.") }

    enum Quality: String, Codable, CaseIterable, Identifiable {
        case poor, fair, good, great
        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        /// A rating for nights that come without one, from time asleep.
        init(hours: Double) {
            switch hours {
            case 8...: self = .great
            case 7..<8: self = .good
            case 6..<7: self = .fair
            default: self = .poor
            }
        }

        var icon: String {
            switch self {
            case .poor: "cloud.fill"
            case .fair: "cloud.sun.fill"
            case .good: "sun.haze.fill"
            case .great: "sun.max.fill"
            }
        }
    }
}
