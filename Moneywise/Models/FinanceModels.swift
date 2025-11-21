import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var localizedTitle: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        }
    }
}

@Model final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var type: TransactionType
    var category: SpendingCategory?
    var account: String
    var date: Date
    var note: String
    var paymentMethod: String
    var isAIGenerated: Bool
    var confidence: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        category: SpendingCategory?,
        account: String,
        date: Date = .now,
        note: String = "",
        paymentMethod: String = "",
        isAIGenerated: Bool = false,
        confidence: Double = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.category = category
        self.account = account
        self.date = date
        self.note = note
        self.paymentMethod = paymentMethod
        self.isAIGenerated = isAIGenerated
        self.confidence = confidence
        self.createdAt = createdAt
    }
}

@Model final class SpendingCategory: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var type: TransactionType

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String, type: TransactionType) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.type = type
    }

    static let defaultCategories: [SpendingCategory] = [
        // Expense Categories
        SpendingCategory(name: "Food & Dining", icon: "🍔", colorHex: "#F97316", type: .expense),
        SpendingCategory(name: "Transport", icon: "🚗", colorHex: "#3B82F6", type: .expense),
        SpendingCategory(name: "Shopping", icon: "🛍️", colorHex: "#EC4899", type: .expense),
        SpendingCategory(name: "Digital", icon: "💻", colorHex: "#8B5CF6", type: .expense),
        SpendingCategory(name: "Entertainment", icon: "🎬", colorHex: "#F59E0B", type: .expense),
        SpendingCategory(name: "Healthcare", icon: "🏥", colorHex: "#EF4444", type: .expense),
        SpendingCategory(name: "Housing", icon: "🏠", colorHex: "#10B981", type: .expense),
        SpendingCategory(name: "Education", icon: "🎓", colorHex: "#6366F1", type: .expense),
        
        // Income Categories
        SpendingCategory(name: "Salary", icon: "💰", colorHex: "#22C55E", type: .income),
        SpendingCategory(name: "Investment", icon: "📈", colorHex: "#14B8A6", type: .income),
        SpendingCategory(name: "Other Income", icon: "💵", colorHex: "#059669", type: .income)
    ]
}

@Model final class Goal: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date
    var note: String

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        deadline: Date,
        note: String = ""
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.note = note
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min((currentAmount as NSDecimalNumber).doubleValue / (targetAmount as NSDecimalNumber).doubleValue, 1)
    }
}

@Model final class AIUsageStats {
    @Attribute(.unique) var id: UUID
    var date: Date
    var inputTokens: Int
    var outputTokens: Int
    var totalCalls: Int

    init(id: UUID = UUID(), date: Date = .now, inputTokens: Int = 0, outputTokens: Int = 0, totalCalls: Int = 0) {
        self.id = id
        self.date = date
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalCalls = totalCalls
    }
}

@Model final class BudgetReminder {
    @Attribute(.unique) var id: UUID
    var scheduledTime: Date
    var enabled: Bool
    var type: ReminderType

    init(id: UUID = UUID(), scheduledTime: Date = .now, enabled: Bool = true, type: ReminderType) {
        self.id = id
        self.scheduledTime = scheduledTime
        self.enabled = enabled
        self.type = type
    }
}

enum ReminderType: String, Codable, Identifiable, CaseIterable {
    case dailyLog
    case savingGoal

    var id: String { rawValue }
    var copy: String {
        switch self {
        case .dailyLog: return "Daily Log Reminder"
        case .savingGoal: return "Savings Goal Reminder"
        }
    }
}

@Model final class SettingItem {
    enum Key: String, Codable, CaseIterable {
        case geminiAPIKey
        case onboardingCompleted
        case lastBackupDate
        case autoImportDuplicates
        case lastTokenSync
    }

    @Attribute(.unique) var id: UUID
    var key: Key
    var value: String

    init(id: UUID = UUID(), key: Key, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}


@Model final class AIInsight {
    enum InsightType: String, Codable {
        case weekly
        case monthly
    }

    @Attribute(.unique) var id: UUID
    var type: InsightType
    var startDate: Date
    var endDate: Date
    var summary: String
    var consumptionInsights: [String]
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        type: InsightType,
        startDate: Date,
        endDate: Date,
        summary: String,
        consumptionInsights: [String],
        generatedAt: Date = .now
    ) {
        self.id = id
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.summary = summary
        self.consumptionInsights = consumptionInsights
        self.generatedAt = generatedAt
    }
}
