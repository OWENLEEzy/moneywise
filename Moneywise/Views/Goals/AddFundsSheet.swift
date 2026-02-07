import SwiftUI
import SwiftData

struct AddFundsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goal: Goal
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @Query private var transactions: [Transaction]
    
    @State private var sliderValue: Double = 0
    @State private var usePercentage = false
    @State private var percentageValue: Double = 50
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var monthlySurplus: Decimal {
        let calendar = Calendar.current
        let now = Date()
        let monthComponent = calendar.dateComponents([.year, .month], from: now)

        guard let startOfMonth = calendar.date(from: monthComponent) else {
            return 0
        }

        let monthlyTransactions = transactions.filter { $0.date >= startOfMonth }
        
        let income = monthlyTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = monthlyTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        
        return max(income - expenses, 0)
    }
    
    private var maxAmount: Decimal {
        monthlySurplus
    }
    
    private var selectedAmount: Decimal {
        if usePercentage {
            return monthlySurplus * Decimal(percentageValue / 100.0)
        } else {
            return Decimal(sliderValue)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Information".localized)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Current Progress".localized)
                            Spacer()
                            Text(goal.currentAmount.coinFormatted)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Target Amount".localized)
                            Spacer()
                            Text(goal.targetAmount.coinFormatted)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("Monthly Surplus".localized)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Available Surplus".localized)
                            Spacer()
                            Text(monthlySurplus.coinFormatted)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .font(.headline)
                        
                        if monthlySurplus <= 0 {
                            Text("No surplus available".localized)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section(header: Text("Add Method".localized)) {
                    Picker("Add Method".localized, selection: $usePercentage) {
                        Text("Fixed Amount".localized).tag(false)
                        Text("Percentage".localized).tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                if usePercentage {
                    Section(header: Text("Percentage".localized)) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Percentage".localized)
                                Spacer()
                                Text("\(Int(percentageValue))%")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $percentageValue, in: 0...100, step: 5)
                                .tint(.blue)
                            
                            HStack {
                                Text("0%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("100%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Section(header: Text("Fixed Amount".localized)) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Fixed Amount".localized)
                                Spacer()
                                Text(Decimal(sliderValue).coinFormatted)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Slider(value: $sliderValue, in: 0...(maxAmount as NSDecimalNumber).doubleValue, step: 10)
                                .tint(.green)
                                .disabled(monthlySurplus <= 0)
                            
                            HStack {
                                Text("¥0")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(maxAmount.coinFormatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if selectedAmount > 0 {
                    Section(header: Text("Preview".localized)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Will Add".localized)
                                Spacer()
                                Text(selectedAmount.coinFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("New Total".localized)
                                Spacer()
                                Text((goal.currentAmount + selectedAmount).coinFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            let newProgress = min((goal.currentAmount + selectedAmount) / goal.targetAmount, 1.0)
                            HStack {
                                Text("New Progress".localized)
                                Spacer()
                                Text("\(Int((newProgress as NSDecimalNumber).doubleValue * 100))%")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        .font(.subheadline)
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
            .navigationTitle("Add Funds".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm".localized) {
                        addFunds()
                    }
                    .disabled(selectedAmount <= 0)
                }
            }
        }
    }
    
    private func addFunds() {
        guard selectedAmount > 0 else {
            showError = true
            errorMessage = "Amount must be greater than 0"
            return
        }
        
        goal.currentAmount += selectedAmount

        // Create corresponding transaction
        let transaction = Transaction(
            amount: selectedAmount,
            type: .expense,
            category: try? context.category(named: "Savings", type: .expense),
            account: "Cash",
            date: Date(),
            note: "Goal funding: \(goal.name)"
        )
        context.insert(transaction)

        if !context.saveSafe() {
            showError = true
            errorMessage = "Save failed"
            return
        }
        dismiss()
    }
}
