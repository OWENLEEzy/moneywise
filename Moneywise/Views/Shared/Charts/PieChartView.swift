import SwiftUI
import Charts

// MARK: - Category Spending Donut Chart

struct CategorySpendingDonutChart: View {
    let transactions: [Transaction]
    @State private var selectedCategory: CategorySpendingData?
    @ObservedObject private var languageManager = LanguageManager.shared

    var chartData: [CategorySpendingData] {
        let expenses = transactions.filter { $0.type == .expense }
        let totalExpense = expenses.reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

        guard totalExpense > 0 else { return [] }

        let grouped = Dictionary(grouping: expenses) { $0.category }

        return grouped.compactMap { (category, trans) -> CategorySpendingData? in
            guard let category = category else { return nil }
            let amount = trans.reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }
            let percentage = (amount / totalExpense) * 100

            // Use category's color or fallback to theme color
            let color: Color
            if let colorHex = category.colorHex.hexColor {
                color = colorHex
            } else {
                // Generate variations of theme color based on percentage
                let opacity = 0.4 + (0.6 * (percentage / 100))
                color = Color(red: 0.2, green: 0.8, blue: 0.6).opacity(max(0.3, min(1.0, opacity)))
            }

            return CategorySpendingData(
                category: category.name,
                amount: amount,
                percentage: percentage,
                color: color,
                icon: category.icon
            )
        }.sorted { $0.amount > $1.amount }
    }

    var totalExpense: Double {
        transactions.filter { $0.type == .expense }
            .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spending by Category".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Total: \(Decimal(totalExpense).coinFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if chartData.isEmpty {
                emptyStateView
            } else {
                HStack(alignment: .center, spacing: 24) {
                    // Donut Chart
                    ZStack {
                        Chart(chartData) { item in
                            SectorMark(
                                angle: .value("Amount", item.amount),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                            .cornerRadius(3)
                            .opacity(selectedCategory == nil || selectedCategory?.id == item.id ? 1.0 : 0.5)
                        }
                        .frame(width: 180, height: 180)
                        .chartAngleSelection(value: .constant(nil))

                        // Center Text
                        VStack(spacing: 2) {
                            if let selected = selectedCategory {
                                Text(selected.icon)
                                    .font(.system(size: 28))
                                Text("\(Int(selected.percentage))%")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(selected.color)
                                Text(selected.category)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            } else {
                                Text("💰")
                                    .font(.system(size: 32))
                                Text(Decimal(totalExpense).coinFormatted)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("Total".localized)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 100)
                    }

                    // Legend List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(chartData) { item in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = selectedCategory?.id == item.id ? nil : item
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        // Color indicator
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(item.color)
                                            .frame(width: 16, height: 16)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(item.icon)
                                                    .font(.system(size: 14))
                                                Text(item.category)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                                            }
                                            Text("\(Decimal(item.amount).coinFormatted) • \(String(format: "%.1f", item.percentage))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        if selectedCategory?.id == item.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedCategory?.id == item.id ?
                                                  item.color.opacity(0.15) :
                                                  Color(UIColor.secondarySystemBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No expense data available".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
}
