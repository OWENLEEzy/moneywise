import SwiftUI
import SwiftData

struct AddFundsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goal: Goal
    
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
        let startOfMonth = calendar.date(from: monthComponent)!
        
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
                Section(header: Text("目标信息")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("当前进度")
                            Spacer()
                            Text(goal.currentAmount.coinFormatted)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("目标金额")
                            Spacer()
                            Text(goal.targetAmount.coinFormatted)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("本月可用结余")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("本月结余")
                            Spacer()
                            Text(monthlySurplus.coinFormatted)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .font(.headline)
                        
                        if monthlySurplus <= 0 {
                            Text("本月暂无结余可用于储蓄")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Section(header: Text("选择添加方式")) {
                    Picker("添加方式", selection: $usePercentage) {
                        Text("固定金额").tag(false)
                        Text("结余比例").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                
                if usePercentage {
                    Section(header: Text("选择结余比例")) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("比例")
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
                    Section(header: Text("选择金额")) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("金额")
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
                    Section(header: Text("预览")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("将添加")
                                Spacer()
                                Text(selectedAmount.coinFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("添加后总额")
                                Spacer()
                                Text((goal.currentAmount + selectedAmount).coinFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            let newProgress = min((goal.currentAmount + selectedAmount) / goal.targetAmount, 1.0)
                            HStack {
                                Text("新进度")
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
            .navigationTitle("添加资金")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
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
            errorMessage = "金额必须大于0"
            return
        }
        
        goal.currentAmount += selectedAmount
        
        do {
            try context.save()
            dismiss()
        } catch {
            showError = true
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
