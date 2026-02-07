import SwiftUI
import SwiftData

struct GoalEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var goal: Goal
    
    @State private var goalName: String
    @State private var targetAmount: String
    @State private var deadline: Date
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(goal: Goal) {
        self.goal = goal
        _goalName = State(initialValue: goal.name)
        _targetAmount = State(initialValue: "\(goal.targetAmount)")
        _deadline = State(initialValue: goal.deadline)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Details")) {
                    TextField("Goal Name", text: $goalName)
                        .autocorrectionDisabled()
                    
                    TextField("Target Amount", text: $targetAmount)
                        .keyboardType(.decimalPad)
                    
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }
                
                if showError {
                    Section {
                        Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Goal".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(goalName.isEmpty || targetAmount.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let amount = Decimal(string: targetAmount) else {
            showError = true
            errorMessage = "Please enter a valid amount"
            return
        }
        
        guard amount > 0 else {
            showError = true
            errorMessage = "Amount must be greater than 0"
            return
        }
        
        goal.name = goalName
        goal.targetAmount = amount
        goal.deadline = deadline

        if !context.saveSafe() {
            showError = true
            errorMessage = "Save failed"
            return
        }
        dismiss()
    }
}
