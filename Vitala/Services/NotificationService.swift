import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func refreshStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = s.authorizationStatus
    }

    func request() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            if granted { scheduleDefaultReminders() }
            return granted
        } catch { return false }
    }

    func scheduleDefaultReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        schedule(identifier: "vitala.water",     hour: 11, minute: 0,  title: "Hydration check 💧", body: "Take a few sips. Your future self thanks you.")
        schedule(identifier: "vitala.move",      hour: 15, minute: 30, title: "Move a little 🌿",   body: "A 5-minute stretch resets your day.")
        schedule(identifier: "vitala.windDown",  hour: 21, minute: 30, title: "Wind down 🌙",        body: "Try a 5-min breathing reset before bed.")
    }

    private func schedule(identifier: String, hour: Int, minute: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var date = DateComponents()
        date.hour = hour; date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
