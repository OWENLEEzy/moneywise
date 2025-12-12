import Foundation
import UserNotifications

final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(at components: DateComponents, body: String) async {
        // Remove existing daily reminder first
        center.removePendingNotificationRequests(withIdentifiers: ["daily-log"])
        
        let content = UNMutableNotificationContent()
        content.title = "Moneywise".localized
        content.body = body
        content.sound = .default
        
        // Ensure we only use hour and minute for the trigger
        let triggerComponents = DateComponents(hour: components.hour, minute: components.minute)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily-log", content: content, trigger: trigger)
        
        do {
            try await center.add(request)
        } catch {
            // Failed to schedule daily reminder
        }
    }

    func scheduleWeeklyGoalReminder(dayOfWeek: Int, time: Date, goals: [Goal]) async {
        // Remove existing weekly reminder
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-goal-progress"])
        
        guard !goals.isEmpty else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Goal Progress".localized
        
        let totalSaved = goals.reduce(0) { $0 + $1.currentAmount }
        let totalTarget = goals.reduce(0) { $0 + $1.targetAmount }
        let progress = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0
        
        let format = "You've achieved %d%% of your total goals! Keep saving! 💰".localized
        content.body = String(format: format, (progress as NSDecimalNumber).intValue)
        content.sound = .default
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var triggerComponents = DateComponents()
        triggerComponents.weekday = dayOfWeek // 1 = Sunday, 2 = Monday, etc.
        triggerComponents.hour = timeComponents.hour
        triggerComponents.minute = timeComponents.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-goal-progress", content: content, trigger: trigger)
        
        do {
            try await center.add(request)
        } catch {
            // Failed to schedule weekly reminder
        }
    }
    
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-log"])
    }
    
    func cancelWeeklyGoalReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-goal-progress"])
    }

    // Deprecated: Individual goal deadline reminders (keeping for backward compatibility if needed, or removing if replaced by weekly)
    // For now, we'll keep the deadline reminder as a separate feature
    func scheduleGoalDeadlineReminder(goal: Goal) async {
        let content = UNMutableNotificationContent()
        content.title = "Goal Deadline Approaching".localized
        
        let format = "%d days left for %@. You're almost there!".localized
        content.body = String(format: format, daysLeft(for: goal), goal.name)
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: goal.deadline)
        components.hour = 9 // Default to 9 AM on the deadline day
        
        // Maybe remind 1 day before?
        if let date = Calendar.current.date(from: components), let reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: date) {
             components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "goal-deadline-\(goal.id)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelGoalDeadlineReminder(goal: Goal) {
        center.removePendingNotificationRequests(withIdentifiers: ["goal-deadline-\(goal.id)"])
    }

    private func daysLeft(for goal: Goal) -> Int {
        let diff = Calendar.current.dateComponents([.day], from: .now, to: goal.deadline)
        return max(diff.day ?? 0, 0)
    }
}

