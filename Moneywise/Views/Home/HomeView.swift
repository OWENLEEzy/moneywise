import SwiftUI
import SwiftData
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var monthlySummary: MonthlySummary = .empty
    @Published var monthOffset: Int = 0 // 0 = current month, -1 = last month, 1 = next month
    @Published var displayMonth: Date = Date()
    
    private var transactions: [Transaction] = []
    
    func update(with transactions: [Transaction], budget: Decimal) {
        self.transactions = transactions
        updateDisplayMonth() // Ensure displayMonth is updated when transactions are updated
        calculateMonthlySummary(budget: budget)
    }
    
    func navigateToNextMonth(budget: Decimal) {
        monthOffset += 1
        updateDisplayMonth()
        calculateMonthlySummary(budget: budget)
    }
    
    func navigateToPreviousMonth(budget: Decimal) {
        monthOffset -= 1
        updateDisplayMonth()
        calculateMonthlySummary(budget: budget)
    }
    
    private func updateDisplayMonth() {
        let calendar = Calendar.current
        displayMonth = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }
    
    private func calculateMonthlySummary(budget: Decimal) {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        let monthComponent = calendar.dateComponents([.year, .month], from: targetDate)

        guard let startOfMonth = calendar.date(from: monthComponent),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            // Fallback to current month if date calculation fails
            self.monthlySummary = MonthlySummary(
                income: 0,
                expenses: 0,
                savedToGoals: 0,
                remainingBudget: budget > 0 ? budget : 0
            )
            return
        }

        let monthlyTransactions = transactions.filter {
            $0.date >= startOfMonth && $0.date <= endOfMonth
        }
        
        let income = monthlyTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        
        // Separate goal savings from regular expenses
        let expenseTransactions = monthlyTransactions.filter { $0.type == .expense }
        let goalSavings = expenseTransactions.filter {
            ($0.note?.contains("Goal funding:") ?? false) || $0.category?.name == "Savings"
        }.reduce(0) { $0 + $1.amount }

        let regularExpenses = expenseTransactions.filter {
            !(($0.note?.contains("Goal funding:") ?? false) || $0.category?.name == "Savings")
        }.reduce(0) { $0 + $1.amount }
        
        // Remaining budget = (Budget > 0 ? Budget : Income) - Spent - SavedToGoals
        let baseAmount = budget > 0 ? budget : income
        let remainingBudget = baseAmount - regularExpenses - goalSavings
        
        self.monthlySummary = MonthlySummary(
            income: income, 
            expenses: regularExpenses, 
            savedToGoals: goalSavings,
            remainingBudget: remainingBudget
        )
    }
}

struct MonthlySummary {
    let income: Decimal
    let expenses: Decimal
    let savedToGoals: Decimal
    let remainingBudget: Decimal
    
    static var empty: MonthlySummary {
        MonthlySummary(income: 0, expenses: 0, savedToGoals: 0, remainingBudget: 0)
    }
}

struct HomeView: View {
    @Binding var showManualSheet: Bool
    @Binding var showAISheet: Bool
    @Binding var toastMessage: String?

    @Query private var transactions: [Transaction]
    @Query private var goals: [Goal]
    @Environment(\.recurringManager) private var recurringManager

    @StateObject private var viewModel = HomeViewModel()
    @ObservedObject private var languageManager = LanguageManager.shared
    @State private var showSettings = false
    @State private var showBudgetSettings = false

    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 0.0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HeroCard(
                        summary: viewModel.monthlySummary,
                        viewModel: viewModel,
                        budget: Decimal(monthlyBudget),
                        showBudgetSettings: $showBudgetSettings
                    )

                    GoalsTicker(goals: goals)

                    // Due soon recurring transactions
                    if !recurringManager?.dueSoon.isEmpty ?? true {
                        DueSoonRecurringView()
                    }

                    BudgetStatusView()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for floating button bar
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Today".localized + ", \(Date().formatted(.dateTime.month().day().locale(LanguageManager.shared.locale)))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                    
                    NavigationLink(destination: AIChatView()) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showBudgetSettings) {
                BudgetSettingsSheet()
            }
            .onAppear {
                viewModel.update(with: transactions, budget: Decimal(monthlyBudget))
            }
            .onChange(of: transactions) {
                viewModel.update(with: transactions, budget: Decimal(monthlyBudget))
                // 同步数据到 Widget
                WidgetDataSync.shared.syncFromTransactions(
                    transactions,
                    budget: Decimal(monthlyBudget),
                    goalsCount: goals.count
                )
            }
            .onChange(of: monthlyBudget) {
                viewModel.update(with: transactions, budget: Decimal(monthlyBudget))
            }
        }
    }
}

struct HeroCard: View {
    let summary: MonthlySummary
    @ObservedObject var viewModel: HomeViewModel
    let budget: Decimal
    @Binding var showBudgetSettings: Bool
    @State private var showRecentTransactions = false
    @ObservedObject private var languageManager = LanguageManager.shared
    @Environment(\.appTheme) private var theme

    private var monthYearText: String {
        return viewModel.displayMonth.formatted(.dateTime.year().month(.wide).locale(languageManager.locale))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with month navigation
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview".localized)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.navigateToPreviousMonth(budget: budget)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(monthYearText)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.navigateToNextMonth(budget: budget)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                Button(action: { showRecentTransactions = true }) {
                    Image(systemName: "ellipsis")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 18, weight: .medium))
                    .padding(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.remainingBudget.coinFormatted)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This month's remaining budget".localized)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 0) {
                // Spent Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Spent".localized)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(summary.expenses.coinFormatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 8)
                
                // Saved to Goals Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "target")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Saved".localized)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(summary.savedToGoals.coinFormatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))
                    .padding(.horizontal, 8)
                
                // Income Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Income".localized)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(summary.income.coinFormatted)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            .padding(.top, 4)
        }
        .padding(24)
        .background(theme.gradient)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        // Swipe left - next month
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.navigateToNextMonth(budget: budget)
                        }
                    } else if value.translation.width > 50 {
                        // Swipe right - previous month
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.navigateToPreviousMonth(budget: budget)
                        }
                    }
                }
        )
        .sheet(isPresented: $showRecentTransactions) {
            RecentTransactionsDetailView()
        }
    }
}

struct GoalsTicker: View {
    let goals: [Goal]
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Goals".localized)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                if goals.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "target")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("No goals yet. Set one up!".localized)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                } else {
                    ForEach(goals) { goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            GoalProgressRow(goal: goal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

struct GoalProgressRow: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🎯")
                    .font(.system(size: 24))
                Text(goal.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.teal]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * goal.progress, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Due Soon Recurring Transactions View

struct DueSoonRecurringView: View {
    @Environment(\.recurringManager) private var recurringManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Due Soon".localized)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            if let dueSoonItems = recurringManager?.dueSoon, !dueSoonItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(dueSoonItems) { recurring in
                        HStack {
                            Text(recurring.categoryIcon)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recurring.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("¥\(String(format: "%.2f", (recurring.amount as NSDecimalNumber).doubleValue))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if recurring.daysUntilDue == 0 {
                                Text("Today".localized)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .cornerRadius(12)
                            } else {
                                Text(String(format: "%d Days".localized, recurring.daysUntilDue))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
                        )
                    }
                }
            }
        }
    }
}

