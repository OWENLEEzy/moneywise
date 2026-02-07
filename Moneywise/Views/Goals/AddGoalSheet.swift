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
                Section(header: Text("Goal Information".localized)) {
                    TextField("Goal Name".localized, text: $goalName)
                        .autocorrectionDisabled()
                    
                    TextField("Target Amount".localized, text: $targetAmount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Deadline".localized, selection: $deadline, displayedComponents: .date)
                }
                
                if showError {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Create New Goal".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) {
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
            errorMessage = "Please enter a valid amount".localized
            return
        }
        
        guard amount > 0 else {
            showError = true
            errorMessage = "Amount must be greater than 0".localized
            return
        }
        
        let goal = Goal(
            name: goalName,
            targetAmount: amount,
            currentAmount: 0,
            deadline: deadline
        )
        
        context.insert(goal)

        if !context.saveSafe() {
            showError = true
            errorMessage = "Save failed: ".localized
            return
        }
        dismiss()
    }
}
