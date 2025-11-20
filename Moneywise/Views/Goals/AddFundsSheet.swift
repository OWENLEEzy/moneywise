import SwiftUI
import SwiftData

struct AddFundsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var goal: Goal
    
    @State private var amount = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("添加资金到目标")) {
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
                
                Section(header: Text("添加金额")) {
                    TextField("输入金额", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .medium))
                    
                    if !amount.isEmpty, let decimalAmount = Decimal(string: amount) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("添加后总额")
                                Spacer()
                                Text((goal.currentAmount + decimalAmount).coinFormatted)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                            
                            let newProgress = min((goal.currentAmount + decimalAmount) / goal.targetAmount, 1.0)
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
                    .disabled(amount.isEmpty)
                }
            }
        }
    }
    
    private func addFunds() {
        guard let decimalAmount = Decimal(string: amount) else {
            showError = true
            errorMessage = "请输入有效的金额"
            return
        }
        
        guard decimalAmount > 0 else {
            showError = true
            errorMessage = "金额必须大于0"
            return
        }
        
        goal.currentAmount += decimalAmount
        
        do {
            try context.save()
            dismiss()
        } catch {
            showError = true
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
