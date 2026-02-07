import SwiftUI
import SwiftData

struct RecentTransactionsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    @State private var transactionToEdit: Transaction?
    @State private var toastMessage: String?
    
    // Get transactions from the last 7 days
    private var recentTransactions: [Transaction] {
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return []
        }
        return transactions.filter { $0.date >= sevenDaysAgo }
    }
    
    // Group transactions by date
    private var groupedTransactions: [(date: Date, transactions: [Transaction])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recentTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.map { (date: $0.key, transactions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(groupedTransactions, id: \.date) { group in
                        DailyTransactionSection(date: group.date, transactions: group.transactions, transactionToEdit: $transactionToEdit)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Recent Transactions".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $transactionToEdit) { transaction in
                ManualEntrySheet(toastMessage: $toastMessage, transactionToEdit: transaction)
            }
            .overlay(alignment: .top) {
                if let message = toastMessage {
                    ToastView(message: message) {
                        toastMessage = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 40)
                }
            }
        }
    }
}

struct DailyTransactionSection: View {
    let date: Date
    let transactions: [Transaction]
    @Binding var transactionToEdit: Transaction?
    
    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
    
    private var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = LanguageManager.shared.locale
        formatter.dateFormat = "EEEE"
        let weekdayFull = formatter.string(from: date)
        // Convert "星期一" to "星期一"
        return weekdayFull
    }
    
    private var monthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM"
        return formatter.string(from: date)
    }
    
    private var dailyIncome: Decimal {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }
    
    private var dailyExpense: Decimal {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Date header
            HStack(alignment: .center, spacing: 8) {
                // Day number
                Text(dayOfMonth)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                // Weekday badge
                Text(weekday)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.6))
                    .cornerRadius(4)
                
                // Month and year
                Text(monthYear)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Daily totals
                HStack(spacing: 16) {
                    // Income
                    Text("¥ \(formatAmount(dailyIncome))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                    
                    // Expense
                    Text("¥ \(formatAmount(dailyExpense))")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            
            Divider()
            
            // Transaction list
            VStack(spacing: 0) {
                ForEach(transactions.sorted(by: { $0.date > $1.date })) { transaction in
                    Button {
                        transactionToEdit = transaction
                    } label: {
                        TransactionDetailRow(transaction: transaction)
                    }
                    
                    if transaction.id != transactions.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
        }
        .cornerRadius(0)
        .padding(.bottom, 8)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

struct TransactionDetailRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            if let category = transaction.category {
                Text(category.icon)
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("❓")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                
                HStack(spacing: 4) {

                    Text(transaction.paymentMethod)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Amount
            Text("¥ \(formatAmount(transaction.amount))")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(transaction.type == .expense ? .red : .blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}
