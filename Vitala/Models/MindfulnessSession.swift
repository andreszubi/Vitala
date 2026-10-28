import Foundation

struct MindfulnessSession: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var subtitle: String
    var minutes: Int
    var category: Category
    var icon: String
    /// Hex colour. Deep enough that white text on it meets WCAG AA.
    var tint: String
    var audioURL: URL?               // optional remote audio

    enum Category: String, Codable, CaseIterable, Identifiable {
        case breathing, focus, sleep, stress, gratitude
        var id: String { rawValue }
        var label: String { rawValue.capitalized }

        /// The breathing rhythm the player guides, in seconds per phase.
        var pattern: [BreathStep] {
            switch self {
            case .breathing, .focus:
                [.init(.inhale, 4), .init(.hold, 4), .init(.exhale, 4), .init(.hold, 4)]
            case .sleep:
                [.init(.inhale, 4), .init(.hold, 7), .init(.exhale, 8)]
            case .stress:
                [.init(.inhale, 4), .init(.exhale, 6)]
            case .gratitude:
                [.init(.inhale, 5), .init(.exhale, 5)]
            }
        }

        /// Gentle cues that rotate during a session.
        var prompts: [String] {
            switch self {
            case .breathing:
                ["Let your shoulders drop.", "Breathe in through your nose.", "Nothing to fix. Just breathe."]
            case .focus:
                ["Name the one thing you'll do next.", "Notice where your attention goes, then return.", "Soften your jaw and eyes."]
            case .sleep:
                ["Let the day go, one breath at a time.", "Feel the weight of your body resting.", "Long, slow exhale."]
            case .stress:
                ["Scan from your forehead down to your feet.", "Wherever you feel tension, breathe into it.", "Your exhale is longer than your inhale."]
            case .gratitude:
                ["Think of someone who made today easier.", "Recall a small moment that felt good.", "What's one thing you're glad you have?"]
            }
        }
    }

    struct BreathStep: Hashable, Codable {
        enum Kind: String, Codable { case inhale, hold, exhale }
        let kind: Kind
        let seconds: Int
        init(_ kind: Kind, _ seconds: Int) { self.kind = kind; self.seconds = seconds }

        var label: String {
            switch kind {
            case .inhale: "Breathe in"
            case .hold: "Hold"
            case .exhale: "Breathe out"
            }
        }
    }
}

enum MindfulnessLibrary {
    static let quickReset = MindfulnessSession(
        title: "Quick reset", subtitle: "One minute of box breathing", minutes: 1,
        category: .breathing, icon: "wind", tint: "#3F7F6E")

    static let all: [MindfulnessSession] = [
        quickReset,
        .init(title: "Box breathing",       subtitle: "4-4-4-4 reset",            minutes: 4,  category: .breathing, icon: "square",             tint: "#2F6B5C"),
        .init(title: "Morning intention",   subtitle: "Set the tone for the day", minutes: 3,  category: .focus,     icon: "sunrise.fill",       tint: "#8A5A1F"),
        .init(title: "Focus before deep work", subtitle: "Anchor your attention", minutes: 8,  category: .focus,     icon: "brain.head.profile", tint: "#2F6B5C"),
        .init(title: "4-7-8 for sleep",     subtitle: "Slow the breath",          minutes: 6,  category: .sleep,     icon: "moon.zzz.fill",      tint: "#3F4A8E"),
        .init(title: "Wind-down for sleep", subtitle: "Release the day",          minutes: 12, category: .sleep,     icon: "moon.stars.fill",    tint: "#343C78"),
        .init(title: "Stress reset",        subtitle: "Longer exhales",           minutes: 5,  category: .stress,    icon: "leaf.fill",          tint: "#4A7F47"),
        .init(title: "Body scan",           subtitle: "Head-to-toe release",      minutes: 10, category: .stress,    icon: "figure.mind.and.body", tint: "#3F6E52"),
        .init(title: "Three good things",   subtitle: "Gratitude prompts",        minutes: 5,  category: .gratitude, icon: "heart.fill",         tint: "#B5503F")
    ]
}

struct LoggedMindfulness: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var sessionId: String
    var title: String
    var minutes: Int
    var completedAt: Date
}
