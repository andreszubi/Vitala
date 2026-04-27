import Foundation

struct SleepEntry: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var bedTime: Date
    var wakeTime: Date
    var quality: Quality
    var notes: String?

    var hours: Double {
        let secs = wakeTime.timeIntervalSince(bedTime)
        return max(0, secs / 3600)
    }

    enum Quality: String, Codable, CaseIterable, Identifiable {
        case poor, fair, good, great
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
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
