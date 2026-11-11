import ActivityKit
import Foundation

/// Starts, updates and ends the Live Activity for the workout or breathing
/// session on screen. If Live Activities are switched off for Vitala,
/// every call does nothing.
@MainActor
final class SessionLiveActivityController {
    typealias State = SessionActivityAttributes.ContentState

    private var activity: Activity<SessionActivityAttributes>?
    private var lastState: State?

    /// Shows the activity. `expectedEnd` is when the session should be over
    /// by; past that the system marks the activity as out of date, in case
    /// the app was closed without ending it.
    func start(kind: SessionActivityAttributes.Kind, name: String, symbol: String, state: State, expectedEnd: Date) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = SessionActivityAttributes(kind: kind, name: name, symbol: symbol)
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: expectedEnd),
                                            pushType: nil)
            lastState = state
        } catch {
            // The session works the same without a Live Activity.
        }
    }

    /// Shows a new state, if it differs from what is showing.
    func update(_ state: State, expectedEnd: Date) {
        guard let activity, state != lastState else { return }
        lastState = state
        Task { await activity.update(ActivityContent(state: state, staleDate: expectedEnd)) }
    }

    /// Takes the activity down: at once, or after leaving a last message
    /// ("Session saved") on the Lock Screen for a couple of minutes.
    func end(showing final: State? = nil) {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task {
            if let final {
                await activity.end(ActivityContent(state: final, staleDate: nil),
                                   dismissalPolicy: .after(.now.addingTimeInterval(120)))
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Ends activities left behind by a session the app was closed in the
    /// middle of. Called at launch.
    static func endLeftovers() {
        Task {
            for activity in Activity<SessionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
