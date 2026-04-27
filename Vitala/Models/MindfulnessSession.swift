import Foundation

struct MindfulnessSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var subtitle: String
    var minutes: Int
    var category: Category
    var icon: String
    var tint: String                 // hex
    var audioURL: URL?               // optional remote audio

    enum Category: String, Codable, CaseIterable, Identifiable {
        case breathing, focus, sleep, stress, gratitude
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
}

enum MindfulnessLibrary {
    static let all: [MindfulnessSession] = [
        .init(title: "Box breathing",      subtitle: "4-4-4-4 reset",    minutes: 4,  category: .breathing, icon: "wind",          tint: "#88B5A6"),
        .init(title: "Focus before deep work", subtitle: "Anchor your attention", minutes: 8, category: .focus,    icon: "brain.head.profile", tint: "#2F6B5C"),
        .init(title: "Wind-down for sleep",subtitle: "Release the day",  minutes: 12, category: .sleep,     icon: "moon.stars.fill", tint: "#3F4A8E"),
        .init(title: "Stress reset",       subtitle: "Body scan",        minutes: 10, category: .stress,    icon: "leaf.fill",     tint: "#7DB37A"),
        .init(title: "Three good things",  subtitle: "Gratitude prompt", minutes: 5,  category: .gratitude, icon: "heart.fill",    tint: "#E8806E")
    ]
}

struct LoggedMindfulness: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var sessionId: String
    var title: String
    var minutes: Int
    var completedAt: Date
}
