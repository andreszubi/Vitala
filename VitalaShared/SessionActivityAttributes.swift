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

    /// What the breath is doing.
    enum Breath: String, Codable, Hashable {
        case breatheIn, holdFull, breatheOut, holdEmpty

        /// "Breathe in"
        var label: String {
            switch self {
            case .breatheIn: "Breathe in"
            case .holdFull, .holdEmpty: "Hold"
            case .breatheOut: "Breathe out"
            }
        }

        /// One word, for the Dynamic Island.
        var word: String {
            switch self {
            case .breatheIn: "In"
            case .holdFull, .holdEmpty: "Hold"
            case .breatheOut: "Out"
            }
        }

        var symbol: String {
            switch self {
            case .breatheIn: "arrow.up"
            case .holdFull, .holdEmpty: "pause.fill"
            case .breatheOut: "arrow.down"
            }
        }

        /// Whether the lungs are full at the end of this phase: the guide
        /// is drawn large for these and small for the others.
        var endsFull: Bool { self == .breatheIn || self == .holdFull }
    }

    /// A stretch of time now under way, such as one breath phase or one
    /// timed exercise. Given as two moments, so the system can animate
    /// through it without the app.
    struct Span: Codable, Hashable {
        var start: Date
        var end: Date
    }

    struct ContentState: Codable, Hashable {
        /// The line that changes: the exercise, or "Breathe in".
        var title: String
        /// Smaller print under it: "Exercise 2 of 5 · 3 × 10 reps".
        var detail: String
        var clock: Clock
        /// The breath phase, for a breathing session that is running.
        var breath: Breath? = nil
        /// The phase or timed exercise now under way.
        var step: Span? = nil
        /// The whole session, start to end, for a breathing session.
        var whole: Span? = nil
        /// Which exercise this is, counting from one, and how many there are.
        var position: Int? = nil
        var count: Int? = nil
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
    /// for a timed exercise, `stepElapsed` and `stepLength` say how far
    /// through it is; both are nil for an exercise counted in reps.
    static func workout(exercise: String, index: Int, count: Int, prescription: String,
                        elapsed: TimeInterval, stepElapsed: TimeInterval? = nil, stepLength: TimeInterval? = nil,
                        isRunning: Bool, now: Date = .now) -> Self {
        var step: SessionActivityAttributes.Span?
        if isRunning, let stepElapsed, let stepLength, stepLength > 0 {
            let done = min(max(0, stepElapsed), stepLength)
            step = .init(start: now.addingTimeInterval(-done), end: now.addingTimeInterval(stepLength - done))
        }
        return Self(title: exercise,
                    detail: prescription,
                    clock: isRunning ? .up(from: now.addingTimeInterval(-elapsed)) : .stopped(seconds: Int(elapsed)),
                    step: step, position: index + 1, count: count, isPaused: !isRunning)
    }

    /// A breathing session in progress: the phase the breath is in, how far
    /// through it, and the session counting down to its end.
    static func breathing(subtitle: String, breath: SessionActivityAttributes.Breath,
                          phaseElapsed: TimeInterval, phaseLength: TimeInterval,
                          elapsed: TimeInterval, total: TimeInterval, isRunning: Bool,
                          now: Date = .now) -> Self {
        let remaining = max(0, total - elapsed)
        guard isRunning else {
            return Self(title: "Paused", detail: subtitle, clock: .stopped(seconds: Int(remaining)), isPaused: true)
        }
        let done = min(max(0, phaseElapsed), max(phaseLength, 0))
        return Self(title: breath.label, detail: subtitle,
                    clock: .down(to: now.addingTimeInterval(remaining)),
                    breath: breath,
                    step: .init(start: now.addingTimeInterval(-done), end: now.addingTimeInterval(phaseLength - done)),
                    whole: .init(start: now.addingTimeInterval(-elapsed), end: now.addingTimeInterval(remaining)))
    }

    /// The last thing shown: the session is over.
    static func finished(_ message: String, seconds: Int) -> Self {
        Self(title: message, detail: "", clock: .stopped(seconds: seconds), isFinished: true)
    }
}
