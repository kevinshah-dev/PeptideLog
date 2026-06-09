import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
        } catch {
            return false
        }
    }

    static func scheduleDoseReminder(_ reminder: DoseReminderSnapshot) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])

        guard reminder.isEnabled else { return }
        guard await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(reminder.peptideName) dose reminder"
        content.body = "\(reminder.formattedDose) scheduled for \(reminder.injectionSite)."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.nextDoseDate
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminder.identifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    static func cancelDoseReminder(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
