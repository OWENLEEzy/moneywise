import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import OSLog

@Observable
final class RecurringManager {
    private(set) var recurringTransactions: [RecurringTransaction] = []
    private var modelContext: ModelContext
    private let logger = Logger(subsystem: "owenlee.Moneywise", category: "RecurringManager")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRecurringTransactions()
    }

    // MARK: - CRUD

    func loadRecurringTransactions() {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        recurringTransactions = (try? modelContext.fetch(descriptor)) ?? []
    }

    func add(_ recurring: RecurringTransaction) {
        modelContext.insert(recurring)
        try? modelContext.save()
        loadRecurringTransactions()
        scheduleNotifications(for: recurring)
    }

    func update(_ recurring: RecurringTransaction) {
        recurring.updatedAt = Date()
        try? modelContext.save()
        loadRecurringTransactions()
        scheduleNotifications(for: recurring)
    }

    func delete(_ recurring: RecurringTransaction) {
        // Cancel notifications
        cancelNotifications(for: recurring)
        modelContext.delete(recurring)
        try? modelContext.save()
        loadRecurringTransactions()
    }

    func toggleActive(_ recurring: RecurringTransaction) {
        recurring.isActive.toggle()
        recurring.updatedAt = Date()
        if !recurring.isActive {
            cancelNotifications(for: recurring)
        } else {
            scheduleNotifications(for: recurring)
        }
        try? modelContext.save()
        loadRecurringTransactions()
    }

    // MARK: - Generation

    /// Generate transactions for all due recurring items
    @discardableResult
    func generateDueTransactions() -> Int {
        var generatedCount = 0
        let now = Date()

        for recurring in recurringTransactions where recurring.isActive {
            if recurring.nextDueDate <= now {
                if let transaction = recurring.generateTransaction(context: modelContext) {
                    modelContext.insert(transaction)
                    generatedCount += 1

                    // Schedule next reminder
                    scheduleNotifications(for: recurring)
                }
            }
        }

        if generatedCount > 0 {
            try? modelContext.save()
            loadRecurringTransactions()
        }

        return generatedCount
    }

    // Get due soon items
    var dueSoon: [RecurringTransaction] {
        recurringTransactions.filter { $0.isActive && $0.isDueSoon }
    }

    // Get active only
    var active: [RecurringTransaction] {
        recurringTransactions.filter { $0.isActive }
    }

    // MARK: - Notifications

    private func scheduleNotifications(for recurring: RecurringTransaction) {
        guard recurring.isActive else { return }

        let center = UNUserNotificationCenter.current()

        // Cancel existing
        cancelNotifications(for: recurring)

        // Only schedule if next due date is in the future
        guard recurring.nextDueDate > Date() else { return }

        // Schedule reminder
        let content = UNMutableNotificationContent()
        content.title = "Recurring Transaction Reminder".localized
        if recurring.type == .expense {
            content.body = String(format: "Will be charged in %d days: %@ ¥%.2f".localized, recurring.daysUntilDue, recurring.name, (recurring.amount as NSDecimalNumber).doubleValue)
        } else {
            content.body = String(format: "Will be received in %d days: %@ ¥%.2f".localized, recurring.daysUntilDue, recurring.name, (recurring.amount as NSDecimalNumber).doubleValue)
        }
        content.sound = .default
        content.userInfo = ["recurringId": recurring.id.uuidString]

        let triggerDate = Calendar.current.date(byAdding: .day, value: -recurring.reminderDaysBefore, to: recurring.nextDueDate) ?? recurring.nextDueDate
        let triggerDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "recurring-\(recurring.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelNotifications(for recurring: RecurringTransaction) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["recurring-\(recurring.id.uuidString)"])
    }
}

// MARK: - Environment Key

private struct RecurringManagerKey: EnvironmentKey {
    static let defaultValue: RecurringManager? = nil
}

extension EnvironmentValues {
    var recurringManager: RecurringManager? {
        get { self[RecurringManagerKey.self] }
        set { self[RecurringManagerKey.self] = newValue }
    }
}
