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
        id: fixedID("Quick reset"), title: "Quick reset", subtitle: "One minute of box breathing", minutes: 1,
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
    ].map {
        // The same ids on every launch, so a logged session or journal
        // entry can always be matched back to its session.
        var session = $0
        session.id = fixedID(session.title)
        return session
    }

    private static func fixedID(_ title: String) -> String {
        "library." + ExerciseVideo.fileName(for: title)
    }
}

struct LoggedMindfulness: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var sessionId: String
    var title: String
    var minutes: Int
    var completedAt: Date
}

/// A stopwatch for a session. It counts wall-clock time rather than ticks,
/// so it stays right while the screen is locked and the app only wakes now
/// and then.
struct SessionClock: Equatable {
    private var accumulated: TimeInterval = 0
    private var runningSince: Date?

    /// Starts running straight away.
    init(startingAt start: Date = .now) {
        runningSince = start
    }

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    mutating func pause(at now: Date) {
        guard let since = runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(since))
        runningSince = nil
    }

    mutating func resume(at now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    /// The longest two readings can be apart while the app is running; a
    /// player reads the clock several times a second.
    static let longestTick: TimeInterval = 3

    /// Leaves out the time between two readings when they are so far apart
    /// that the app must have been suspended in between: nothing was playing
    /// then, so it doesn't count.
    mutating func leaveOutGap(since last: Date, until now: Date) {
        let gap = now.timeIntervalSince(last)
        guard gap > Self.longestTick, let since = runningSince else { return }
        // Never push the start past now, however odd the two readings are.
        runningSince = min(now, since.addingTimeInterval(gap))
    }
}
