// BudgetStatusView.swift
import SwiftUI
import SwiftData

struct BudgetStatusView: View {
    @Query private var budgets: [Budget]
    @State private var showAllBudgets = false

    var activeBudgets: [Budget] {
        budgets.filter { $0.isActive }
    }

    var overBudgetCount: Int {
        activeBudgets.filter { $0.isOverBudget }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Budget Status")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                if overBudgetCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(overBudgetCount) over budget")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            if activeBudgets.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.4))
                        Text("No active budgets")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Button("Set up a budget") {
                            showAllBudgets = true
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 32)
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(activeBudgets.prefix(3)) { budget in
                        CompactBudgetRow(budget: budget)
                    }

                    if activeBudgets.count > 3 {
                        Button(action: { showAllBudgets = true }) {
                            Text("View all \(activeBudgets.count) budgets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAllBudgets) {
            BudgetManagementView()
        }
    }
}

struct CompactBudgetRow: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text(budget.category?.icon ?? "💰")
                        .font(.system(size: 16))
                    Text(budget.displayName)
                        .font(.system(size: 14, weight: .medium))
                }
                Spacer()
                Text("\(Int(budget.percentageUsed * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(budget.isOverBudget ? .red : budget.percentageUsed > 0.8 ? .orange : .green)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(budget.isOverBudget ? Color.red : gradient)
                        .frame(width: geometry.size.width * min(budget.percentageUsed, 1), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(budget.currentSpending.coinFormatted) / \(budget.limit.coinFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        )
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

#Preview {
    BudgetStatusView()
        .modelContainer(for: [Budget.self], inMemory: true)
}
