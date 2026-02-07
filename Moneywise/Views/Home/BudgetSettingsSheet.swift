import SwiftUI
import SwiftData

struct BudgetSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var transactions: [Transaction]
    
    @AppStorage("monthlyBudget") private var savedBudget: Double = 0.0
    
    @State private var monthlyBudget = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var currentMonthStats: (income: Decimal, expenses: Decimal) {
        let calendar = Calendar.current
        let now = Date()
        let monthComponent = calendar.dateComponents([.year, .month], from: now)

        guard let startOfMonth = calendar.date(from: monthComponent) else {
            return (0, 0)
        }

        let monthlyTransactions = transactions.filter { $0.date >= startOfMonth }
        
        let income = monthlyTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = monthlyTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        
        return (income, expenses)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Monthly Statistics")) {
                    HStack {
                        Text("Income")
                        Spacer()
                        Text(currentMonthStats.income.coinFormatted)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Text("Expenses")
                        Spacer()
                        Text(currentMonthStats.expenses.coinFormatted)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text((currentMonthStats.income - currentMonthStats.expenses).coinFormatted)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Budget Settings")) {
                    TextField("Monthly Budget", text: $monthlyBudget)
                        .keyboardType(.decimalPad)
                    
                    Text("Set a monthly spending limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Budget Suggestion")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Suggested Budget")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        let suggestedBudget = currentMonthStats.income * 0.7
                        Text("Based on your income, a suggested budget is \(suggestedBudget.coinFormatted) (70% of income)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Use Suggested Budget") {
                            monthlyBudget = String(describing: suggestedBudget)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
                
                if showError {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Budget Management".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(monthlyBudget.isEmpty)
                }
            }
            .onAppear {
                if savedBudget > 0 {
                    monthlyBudget = String(savedBudget)
                }
            }
        }
    }
    
    private func saveBudget() {
        guard let budget = Double(monthlyBudget) else {
            showError = true
            errorMessage = "Please enter a valid amount"
            return
        }
        
        guard budget > 0 else {
            showError = true
            errorMessage = "Budget must be greater than 0"
            return
        }
        
        savedBudget = budget
        dismiss()
    }
}
