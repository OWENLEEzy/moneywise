import SwiftUI
import SwiftData

struct AddGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var goalName = ""
    @State private var targetAmount = ""
    @State private var deadline = Date().addingTimeInterval(30 * 24 * 3600) // 30 days from now
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("目标信息")) {
                    TextField("目标名称", text: $goalName)
                        .autocorrectionDisabled()
                    
                    TextField("目标金额", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("截止日期", selection: $deadline, displayedComponents: .date)
                }
                
                if showError {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("新建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveGoal()
                    }
                    .disabled(goalName.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
    
    private func saveGoal() {
        guard let amount = Decimal(string: targetAmount) else {
            showError = true
            errorMessage = "请输入有效的金额"
            return
        }
        
        guard amount > 0 else {
            showError = true
            errorMessage = "金额必须大于0"
            return
        }
        
        let goal = Goal(
            name: goalName,
            targetAmount: amount,
            currentAmount: 0,
            deadline: deadline
        )
        
        context.insert(goal)
        
        do {
            try context.save()
            dismiss()
        } catch {
            showError = true
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}
