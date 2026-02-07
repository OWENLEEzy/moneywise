// BudgetManagementView.swift
import SwiftUI
import SwiftData

struct BudgetManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Budget.startDate, order: .reverse) private var budgets: [Budget]
    @Query private var categories: [SpendingCategory]

    @State private var showAddBudget = false
    @State private var editingBudget: Budget?

    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive }
    }

    var inactiveBudgets: [Budget] {
        budgets.filter { !$0.isActive && $0.isEnabled }
    }

    var body: some View {
        List {
            if budgets.isEmpty {
                ContentUnavailableView {
                    Label("No Budgets", systemImage: "chart.bar")
                } description: {
                    Text("Create a budget to track your spending limits.")
                }
            } else {
                // Active Budgets Section
                if !activeBudgets.isEmpty {
                    Section(header: Text("Active Budgets")) {
                        ForEach(activeBudgets) { budget in
                            BudgetRow(budget: budget)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingBudget = budget
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteBudget(budget)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editingBudget = budget
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }

                // Inactive/Expired Budgets Section
                if !inactiveBudgets.isEmpty {
                    Section(header: Text("Inactive Budgets")) {
                        ForEach(inactiveBudgets) { budget in
                            BudgetRow(budget: budget)
                                .opacity(0.7)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingBudget = budget
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteBudget(budget)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Budgets")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddBudget = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddBudget) {
            BudgetEditorSheet(categories: categories.filter { $0.type == .expense })
        }
        .sheet(item: $editingBudget) { budget in
            BudgetEditorSheet(
                budget: budget,
                categories: categories.filter { $0.type == .expense }
            )
        }
    }

    private func deleteBudget(_ budget: Budget) {
        withAnimation {
            context.delete(budget)
            context.saveSafe()
        }
    }
}

struct BudgetRow: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Text(budget.category?.icon ?? "💰")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(budget.displayName)
                            .font(.headline)
                        Text(budget.period.localizedTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(budget.remainingAmount.coinFormatted)
                        .font(.headline)
                        .foregroundColor(budget.isOverBudget ? .red : .green)
                    Text("\(Int(budget.percentageUsed * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(budget.isOverBudget ? Color.red : gradient)
                        .frame(width: geometry.size.width * min(budget.percentageUsed, 1), height: 8)

                    // Over-budget indicator
                    if budget.isOverBudget {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red.opacity(0.3))
                            .frame(width: geometry.size.width, height: 8)
                    }
                }
            }
            .frame(height: 8)

            // Details
            HStack {
                Text("Spent: \(budget.currentSpending.coinFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Limit: \(budget.limit.coinFormatted)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.2, green: 0.8, blue: 0.6),
                Color(red: 0.1, green: 0.6, blue: 0.5)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Budget Editor Sheet

struct BudgetEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var budget: Budget?
    let categories: [SpendingCategory]

    @State private var selectedCategory: SpendingCategory?
    @State private var selectedPeriod: BudgetPeriod = .monthly
    @State private var limit: String = ""
    @State private var isEnabled: Bool = true
    @State private var startDate: Date = Date()
    @State private var endDate: Date = {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }()

    private var isEditing: Bool { budget != nil }

    init(budget: Budget? = nil, categories: [SpendingCategory]) {
        self.budget = budget
        self.categories = categories
        _selectedCategory = State(initialValue: budget?.category)
        _selectedPeriod = State(initialValue: budget?.period ?? .monthly)
        _limit = State(initialValue: budget?.limit.description ?? "")
        _isEnabled = State(initialValue: budget?.isEnabled ?? true)
        _startDate = State(initialValue: budget?.startDate ?? Date())
        _endDate = State(initialValue: budget?.endDate ?? {
            let calendar = Calendar.current
            return calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        }())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Budget Details")) {
                    // Category Selection (optional - nil means total budget)
                    Picker("Category", selection: $selectedCategory) {
                        Text("Total Budget (All Categories)").tag(nil as SpendingCategory?)
                        ForEach(categories) { category in
                            HStack {
                                Text(category.icon)
                                Text(category.name)
                            }
                            .tag(category as SpendingCategory?)
                        }
                    }

                    // Period Selection
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(BudgetPeriod.allCases) { period in
                            Text(period.localizedTitle).tag(period)
                        }
                    }

                    // Limit Input
                    HStack {
                        Text("Limit")
                        Spacer()
                        TextField("0.00", text: $limit)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }

                    // Enable/Disable
                    Toggle("Enabled", isOn: $isEnabled)
                }

                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)

                    // Quick select buttons
                    HStack {
                        Text("Quick Set:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("This Month") {
                            setToThisMonth()
                        }
                        .font(.caption)
                        Button("Next Month") {
                            setToNextMonth()
                        }
                        .font(.caption)
                        Button("This Year") {
                            setToThisYear()
                        }
                        .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBudget()
                    }
                    .disabled(limit.isEmpty || Decimal(string: limit) == nil)
                }
            }
        }
    }

    private func saveBudget() {
        guard let limitValue = Decimal(string: limit) else { return }

        if let existing = budget {
            // Update existing
            existing.category = selectedCategory
            existing.period = selectedPeriod
            existing.limit = limitValue
            existing.isEnabled = isEnabled
            existing.startDate = startDate
            existing.endDate = endDate
        } else {
            // Create new
            let newBudget = Budget(
                category: selectedCategory,
                period: selectedPeriod,
                limit: limitValue,
                startDate: startDate,
                endDate: endDate,
                isEnabled: isEnabled
            )
            context.insert(newBudget)
        }

        context.saveSafe()
        dismiss()
    }

    private func setToThisMonth() {
        let calendar = Calendar.current
        let now = Date()
        startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? now
    }

    private func setToNextMonth() {
        let calendar = Calendar.current
        let now = Date()
        startDate = calendar.date(byAdding: .month, value: 1, to: now) ?? now
        let startOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)) ?? startDate
        endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfNextMonth) ?? startDate
    }

    private func setToThisYear() {
        let calendar = Calendar.current
        let now = Date()
        startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        endDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate) ?? now
    }
}

#Preview {
    NavigationStack {
        BudgetManagementView()
    }
    .modelContainer(for: [Budget.self, SpendingCategory.self], inMemory: true)
}
