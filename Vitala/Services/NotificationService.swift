import Foundation
import UserNotifications

/// A daily nudge the user can switch on and schedule.
struct Reminder: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case water, move, windDown
    }

    var kind: Kind
    var isOn: Bool
    var hour: Int
    var minute: Int

    var id: String { "vitala.reminder.\(kind.rawValue)" }

    var label: String {
        switch kind {
        case .water: "Hydration"
        case .move: "Movement break"
        case .windDown: "Wind down"
        }
    }

    var icon: String {
        switch kind {
        case .water: "drop.fill"
        case .move: "figure.walk"
        case .windDown: "moon.stars.fill"
        }
    }

    var title: String {
        switch kind {
        case .water: "Hydration check"
        case .move: "Move a little"
        case .windDown: "Time to wind down"
        }
    }

    var body: String {
        switch kind {
        case .water: "Take a few sips. Your future self thanks you."
        case .move: "A five-minute stretch resets your afternoon."
        case .windDown: "Try a short breathing session before bed."
        }
    }

    static let defaults: [Reminder] = [
        Reminder(kind: .water, isOn: true, hour: 11, minute: 0),
        Reminder(kind: .move, isOn: true, hour: 15, minute: 30),
        Reminder(kind: .windDown, isOn: true, hour: 21, minute: 30)
    ]
}

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var reminders: [Reminder]

    nonisolated static let storageKey = "vitala.reminders.v1"
    /// Requests scheduled by versions before 1.0.
    nonisolated static let legacyIdentifiers = ["vitala.water", "vitala.move", "vitala.windDown"]
    private let center = UNUserNotificationCenter.current()

    var isAllowed: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = saved
        } else {
            reminders = Reminder.defaults
        }
    }

    func refreshStatus() async {
        let s = await center.notificationSettings()
        authorizationStatus = s.authorizationStatus
    }

    /// Asks for permission (only shows the system prompt the first time) and
    /// schedules the enabled reminders if granted.
    @discardableResult
    func request() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        await reschedule()
        return granted
    }

    func update(_ reminder: Reminder) async {
        guard let i = reminders.firstIndex(where: { $0.kind == reminder.kind }) else { return }
        reminders[i] = reminder
        persist()
        if reminder.isOn && authorizationStatus == .notDetermined {
            await request()
        } else {
            await reschedule()
        }
    }

    /// Replaces Vitala's pending requests with the enabled reminders.
    func reschedule() async {
        center.removePendingNotificationRequests(withIdentifiers: Reminder.Kind.allCases.map {
            Reminder(kind: $0, isOn: false, hour: 0, minute: 0).id
        } + Self.legacyIdentifiers)
        guard isAllowed else { return }
        for reminder in reminders where reminder.isOn {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            var date = DateComponents()
            date.hour = reminder.hour
            date.minute = reminder.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    /// Cancels everything and restores default reminder settings.
    func reset() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        reminders = Reminder.defaults
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
