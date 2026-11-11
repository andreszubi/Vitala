import ActivityKit
import Foundation

/// What a Live Activity shows for a workout or a breathing session. Shared
/// by the app, which starts and updates it, and the widget extension, which
/// draws it on the Lock Screen and in the Dynamic Island.
struct SessionActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable {
        case workout, breathing
    }

    /// The clock on the activity. A running clock is given as a moment in
    /// time, so the system can keep it ticking without the app.
    enum Clock: Codable, Hashable {
        /// Counting down to this moment (a breathing session's end).
        case down(to: Date)
        /// Counting up from this moment (a workout's start, moved later by
        /// any time spent paused).
        case up(from: Date)
        /// Not moving: paused or finished at this many seconds.
        case stopped(seconds: Int)
    }

    struct ContentState: Codable, Hashable {
        /// The line that changes: the exercise, or what the breath is doing.
        var title: String
        /// Smaller print under it: "Exercise 2 of 5 · 3 × 10 reps".
        var detail: String
        var clock: Clock
        /// For a timed exercise that is running: when it ends.
        var stepEndsAt: Date? = nil
        var isPaused: Bool = false
        var isFinished: Bool = false
    }

    var kind: Kind
    /// The workout's or session's name.
    var name: String
    /// An SF Symbol for it.
    var symbol: String
}

extension SessionActivityAttributes.ContentState {
    /// A workout in progress. `elapsed` is the time on the workout's clock;
    /// `stepRemaining` is what is left of a timed exercise, nil for reps.
    static func workout(exercise: String, index: Int, count: Int, prescription: String,
                        elapsed: TimeInterval, stepRemaining: TimeInterval?, isRunning: Bool,
                        now: Date = .now) -> Self {
        Self(title: exercise,
             detail: "Exercise \(index + 1) of \(count) · \(prescription)",
             clock: isRunning ? .up(from: now.addingTimeInterval(-elapsed)) : .stopped(seconds: Int(elapsed)),
             stepEndsAt: isRunning ? stepRemaining.map { now.addingTimeInterval(max(0, $0)) } : nil,
             isPaused: !isRunning)
    }

    /// A breathing session in progress, counting down to its end.
    static func breathing(subtitle: String, elapsed: TimeInterval, total: TimeInterval, isRunning: Bool,
                          now: Date = .now) -> Self {
        let remaining = max(0, total - elapsed)
        return Self(title: isRunning ? "Breathe with the guide" : "Paused",
                    detail: subtitle,
                    clock: isRunning ? .down(to: now.addingTimeInterval(remaining)) : .stopped(seconds: Int(remaining)),
                    isPaused: !isRunning)
    }

    /// The last thing shown: the session is over.
    static func finished(_ message: String, seconds: Int) -> Self {
        Self(title: message, detail: "", clock: .stopped(seconds: seconds), isFinished: true)
    }
}
