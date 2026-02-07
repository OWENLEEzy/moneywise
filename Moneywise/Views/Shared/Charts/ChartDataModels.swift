import SwiftUI

// MARK: - Chart Data Models

struct MonthlySpendingData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
    let date: Date
}

struct CategorySpendingData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
    let icon: String
}

struct IncomeExpenseData: Identifiable {
    let id = UUID()
    let period: String
    let income: Double
    let expense: Double
    let date: Date
}

struct DailySpendingData: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
    let date: Date
}
