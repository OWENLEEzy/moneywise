import SwiftUI
import SwiftData

struct AddRecurringTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.recurringManager) private var manager
    @Environment(\.dismiss) private var dismiss

    @Query private var categories: [SpendingCategory]

    @State private var name = ""
    @State private var amount = ""
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: SpendingCategory?
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var reminderDaysBefore = 1

    @State private var showingError = false
    @State private var errorMessage = ""

    var filteredCategories: [SpendingCategory] {
        categories.filter { $0.type == type }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("名称", text: $name)
                        .textFieldStyle(.plain)

                    TextField("金额", text: $amount)
                        .textFieldStyle(.plain)
                        .keyboardType(.decimalPad)

                    Picker("类型", selection: $type) {
                        Text("支出").tag(TransactionType.expense)
                        Text("收入").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)

                    Picker("分类", selection: $selectedCategory) {
                        Text("选择分类").tag(nil as SpendingCategory?)
                        ForEach(filteredCategories) { category in
                            Text("\(category.icon) \(category.name)").tag(category as SpendingCategory?)
                        }
                    }
                }

                Section("周期设置") {
                    Picker("频率", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { freq in
                            Label(freq.localizedName, systemImage: freq.icon)
                                .tag(freq)
                        }
                    }

                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)

                    Toggle("设置结束日期", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("提醒") {
                    Stepper("提前 \(reminderDaysBefore) 天提醒", value: $reminderDaysBefore, in: 0...7)
                }
            }
            .navigationTitle("添加定期交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveRecurringTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    var isValid: Bool {
        !name.isEmpty &&
        !amount.isEmpty &&
        (Double(amount) != nil) &&
        selectedCategory != nil
    }

    private func saveRecurringTransaction() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "请输入有效金额"
            showingError = true
            return
        }

        guard let category = selectedCategory else {
            errorMessage = "请选择分类"
            showingError = true
            return
        }

        let recurring = RecurringTransaction(
            name: name,
            amount: Decimal(amountValue),
            category: category,
            type: type,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            reminderDaysBefore: reminderDaysBefore
        )

        manager?.add(recurring)
        dismiss()
    }
}

#Preview {
    AddRecurringTransactionSheet()
}
