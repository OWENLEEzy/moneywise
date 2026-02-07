import Foundation
import SwiftData

@Model
final class RecurringTransaction: Identifiable {
    // Basic info
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var categoryName: String  // Store category name as string
    var categoryIcon: String  // Store category icon as string
    var typeRawValue: String  // "income" or "expense"

    // Schedule
    var frequencyRawValue: String  // "daily", "weekly", "biweekly", "monthly", "quarterly", "yearly"
    var interval: Int  // Every N periods (default: 1)
    var startDate: Date
    var endDate: Date?  // Optional end date
    var lastGeneratedDate: Date?
    var nextDueDate: Date

    // State
    var isActive: Bool
    var reminderDaysBefore: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: SpendingCategory,
        type: TransactionType,
        frequency: RecurringFrequency,
        interval: Int = 1,
        startDate: Date,
        endDate: Date? = nil,
        reminderDaysBefore: Int = 1
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.categoryName = category.name
        self.categoryIcon = category.icon
        self.typeRawValue = type == .income ? "income" : "expense"
        self.frequencyRawValue = frequency.rawValue
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.lastGeneratedDate = nil
        self.nextDueDate = startDate
        self.isActive = true
        self.reminderDaysBefore = reminderDaysBefore
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Computed properties
    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRawValue) ?? .monthly }
        set { frequencyRawValue = newValue.rawValue }
    }

    var type: TransactionType {
        get { typeRawValue == "income" ? .income : .expense }
        set { typeRawValue = newValue == .income ? "income" : "expense" }
    }

    // Calculate next due date
    func calculateNextDueDate(from date: Date) -> Date? {
        // Check if we've passed end date
        if let endDate = endDate, date > endDate {
            return nil
        }

        let calendar = Calendar.current
        var nextDate = date

        switch frequency {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .biweekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 2 * interval, to: date) ?? date
        case .monthly:
            nextDate = calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .quarterly:
            nextDate = calendar.date(byAdding: .month, value: 3 * interval, to: date) ?? date
        case .yearly:
            nextDate = calendar.date(byAdding: .year, value: interval, to: date) ?? date
        }

        // Check if next date exceeds end date
        if let endDate = endDate, nextDate > endDate {
            return nil
        }

        return nextDate
    }

    // Check if due date is approaching
    var isDueSoon: Bool {
        let calendar = Calendar.current
        let now = Date()
        let daysUntilDue = calendar.dateComponents([.day], from: now, to: nextDueDate).day ?? 0
        return daysUntilDue <= reminderDaysBefore && daysUntilDue >= 0
    }

    // Days until due
    var daysUntilDue: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: now, to: nextDueDate).day ?? 0
    }

    // Generate actual transaction
    func generateTransaction(context: ModelContext) -> Transaction? {
        // Find or create category
        let descriptor = FetchDescriptor<SpendingCategory>(
            predicate: #Predicate<SpendingCategory> { $0.name == categoryName }
        )

        guard let category = try? context.fetch(descriptor).first else {
            return nil
        }

        let transaction = Transaction(
            amount: amount,
            type: type,
            category: category,
            account: "Cash",
            date: nextDueDate,
            note: "定期交易: \(name)",
            paymentMethod: "Auto",
            isAIGenerated: false,
            confidence: 1.0
        )

        lastGeneratedDate = nextDueDate

        // Calculate next due date
        if let next = calculateNextDueDate(from: nextDueDate) {
            nextDueDate = next
        } else {
            isActive = false  // End date reached
        }

        updatedAt = Date()

        return transaction
    }
}

enum RecurringFrequency: String, CaseIterable, Identifiable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"

    var id: String { rawValue }

    var localizedName: LocalizedStringResource {
        switch self {
        case .daily: return "每天"
        case .weekly: return "每周"
        case .biweekly: return "每两周"
        case .monthly: return "每月"
        case .quarterly: return "每季度"
        case .yearly: return "每年"
        }
    }

    var icon: String {
        switch self {
        case .daily: return "📅"
        case .weekly: return "📆"
        case .biweekly: return "📋"
        case .monthly: return "🗓️"
        case .quarterly: return "📊"
        case .yearly: return "📈"
        }
    }
}
