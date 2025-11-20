import SwiftUI
import SwiftData
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var monthlySummary: MonthlySummary = .empty
    
    private var transactions: [Transaction] = []
    
    func update(with transactions: [Transaction]) {
        self.transactions = transactions
        calculateMonthlySummary()
    }
    
    private func calculateMonthlySummary() {
        let calendar = Calendar.current
        let now = Date()
        let monthComponent = calendar.dateComponents([.year, .month], from: now)
        let startOfMonth = calendar.date(from: monthComponent)!
        
        let monthlyTransactions = transactions.filter { $0.date >= startOfMonth }
        
        let income = monthlyTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expenses = monthlyTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        
        // Let's assume a dummy budget for now
        let budget: Decimal = 10000
        let remainingBudget = budget - expenses
        
        self.monthlySummary = MonthlySummary(income: income, expenses: expenses, remainingBudget: remainingBudget)
    }
}

struct MonthlySummary {
    let income: Decimal
    let expenses: Decimal
    let remainingBudget: Decimal
    
    static var empty: MonthlySummary {
        MonthlySummary(income: 0, expenses: 0, remainingBudget: 0)
    }
}

struct HomeView: View {
    @Binding var showManualSheet: Bool
    @Binding var showAISheet: Bool
    @Binding var toastMessage: String?
    
    @Query private var transactions: [Transaction]
    @Query private var goals: [Goal]
    
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    HeroCard(summary: viewModel.monthlySummary)
                    
                    GoalsTicker(goals: goals)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // Space for floating button bar
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Today, \(Date().formatted(.dateTime.month().day()))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                viewModel.update(with: transactions)
            }
            .onChange(of: transactions) {
                viewModel.update(with: transactions)
            }
        }
    }
}

struct HeroCard: View {
    let summary: MonthlySummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Assets overview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 18, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.remainingBudget.coinFormatted)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This month's remaining budget")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.vertical, 8)
            
            // Custom progress bar with gradient
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    let totalAmount = (summary.expenses + summary.remainingBudget as NSDecimalNumber).doubleValue
                    let spentAmount = (summary.expenses as NSDecimalNumber).doubleValue
                    let progress = totalAmount > 0 ? spentAmount / totalAmount : 0
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.red.opacity(0.8), Color.orange.opacity(0.9)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(summary.expenses.coinFormatted)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Income")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Text(summary.income.coinFormatted)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.8, blue: 0.6),
                    Color(red: 0.1, green: 0.6, blue: 0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 5)
    }
}

struct GoalsTicker: View {
    let goals: [Goal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Goals")
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
                            Text("No goals yet. Set one up!")
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
