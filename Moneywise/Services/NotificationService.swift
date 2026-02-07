//
//  NotificationService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Local notification scheduling service for reminders
//

import Foundation
import UserNotifications

/// # NotificationScheduler
///
/// ## Overview
/// Service responsible for scheduling and managing local notifications for the app.
/// Handles daily logging reminders, weekly goal progress summaries, and individual
/// goal deadline reminders.
///
/// ## Usage
/// ```swift
/// let scheduler = NotificationScheduler()
///
/// // Request permission first
/// let granted = await scheduler.requestAuthorization()
/// guard granted else { return }
///
/// // Schedule daily reminder at 9 PM
/// let components = DateComponents(hour: 21, minute: 0)
/// await scheduler.scheduleDailyReminder(
///     at: components,
///     body: "Don't forget to log your transactions today!"
/// )
///
/// // Cancel daily reminder
/// scheduler.cancelDailyReminder()
/// ```
///
/// ## Error Handling
/// - Authorization failures are silent (check return value of `requestAuthorization()`)
/// - Scheduling failures are logged but don't throw
/// - Uses `UNUserNotificationCenter` for all operations
///
/// ## Thread Safety
/// This class is not thread-safe. All methods should be called from the main thread.
/// Async methods handle threading internally via `await`.
///
/// ## Dependencies
/// - UserNotifications: UNUserNotificationCenter for notification management
/// - Foundation: DateComponents for scheduling
///
/// ## Notification Identifiers
/// - "daily-log": Daily transaction logging reminder
/// - "weekly-goal-progress": Weekly goal progress summary
/// - "goal-deadline-{id}": Individual goal deadline reminder
///
/// ## Permissions
/// Requires notification permission to be granted before scheduling.
/// Call `requestAuthorization()` before any scheduling operations.

/// Service for scheduling and managing local notifications
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    /// Requests notification authorization from the user
    ///
    /// Must be called before scheduling any notifications. Presents the system
    /// permission dialog on first request.
    ///
    /// - Returns: true if authorization granted (or previously granted), false otherwise
    /// - Note: Subsequent calls return cached result without showing dialog
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    /// Schedules a daily repeating reminder at a specific time
    ///
    /// Removes any existing daily reminder before scheduling the new one.
    /// The notification repeats daily at the specified time.
    ///
    /// - Parameters:
    ///   - components: DateComponents with hour and minute set (other components ignored)
    ///   - body: Notification body text (title is localized "Moneywise")
    /// - Note: Uses identifier "daily-log" - replaces any existing daily reminder
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

    /// Schedules a weekly goal progress summary notification
    ///
    /// Calculates total savings progress across all goals and sends a summary
    /// on the specified day of week.
    ///
    /// - Parameters:
    ///   - dayOfWeek: Day of week (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    ///   - time: Time of day for the notification
    ///   - goals: Array of goals to calculate progress from
    /// - Note: Uses identifier "weekly-goal-progress" - replaces any existing weekly reminder
    /// - Important: Empty goals array results in no notification being scheduled
    func scheduleWeeklyGoalReminder(dayOfWeek: Int, time: Date, goals: [Goal]) async {
        // Remove existing weekly reminder
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-goal-progress"])

        guard !goals.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Goal Progress".localized

        let totalSaved = goals.reduce(0) { $0 + $1.currentAmount }
        let totalTarget = goals.reduce(0) { $0 + $1.targetAmount }
        let progress = totalTarget > 0 ? (totalSaved / totalTarget) * 100 : 0

        let format = "You've achieved %d%% of your total goals! Keep saving!".localized
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

    /// Cancels the daily logging reminder
    ///
    /// Removes the "daily-log" notification if it exists.
    /// Safe to call even if no reminder is scheduled.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-log"])
    }

    /// Cancels the weekly goal progress reminder
    ///
    /// Removes the "weekly-goal-progress" notification if it exists.
    /// Safe to call even if no reminder is scheduled.
    func cancelWeeklyGoalReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-goal-progress"])
    }

    /// Schedules a one-time reminder for a goal's deadline
    ///
    /// Schedules a notification for the day before the goal deadline at 9 AM.
    /// Useful for reminding users about upcoming goal due dates.
    ///
    /// - Parameter goal: The goal to create a deadline reminder for
    /// - Note: Uses identifier "goal-deadline-{goal.id}" for cancellation
    /// - Important: Schedules for day BEFORE deadline at 9 AM
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

    /// Cancels a goal's deadline reminder
    ///
    /// - Parameter goal: The goal whose reminder should be cancelled
    /// - Note: Safe to call even if no reminder exists for the goal
    func cancelGoalDeadlineReminder(goal: Goal) {
        center.removePendingNotificationRequests(withIdentifiers: ["goal-deadline-\(goal.id)"])
    }

    /// Calculates days remaining until a goal deadline
    ///
    /// - Parameter goal: The goal to calculate days remaining for
    /// - Returns: Number of days (0 if deadline has passed)
    private func daysLeft(for goal: Goal) -> Int {
        let diff = Calendar.current.dateComponents([.day], from: .now, to: goal.deadline)
        return max(diff.day ?? 0, 0)
    }
}
