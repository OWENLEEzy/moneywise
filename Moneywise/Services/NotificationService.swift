import Foundation
import UserNotifications

final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    func scheduleDailyReminder(at components: DateComponents, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = "GemBudget"
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-log-\(components.hour ?? 0)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func scheduleGoalReminder(goal: Goal) async {
        let content = UNMutableNotificationContent()
        content.title = "储蓄目标提醒"
        content.body = "距离 \(goal.name) 截止还有 \(daysLeft(for: goal)) 天，一起加油！"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: goal.deadline)
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "goal-\(goal.id)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelGoalReminder(goal: Goal) {
        center.removePendingNotificationRequests(withIdentifiers: ["goal-\(goal.id)"])
    }

    private func daysLeft(for goal: Goal) -> Int {
        let diff = Calendar.current.dateComponents([.day], from: .now, to: goal.deadline)
        return max(diff.day ?? 0, 0)
    }
}

