import SwiftUI
import Charts

// MARK: - Income vs Expense Bar Chart

struct IncomeExpenseBarChart: View {
    let transactions: [Transaction]
    @State private var selectedPeriod: IncomeExpenseData?
    @ObservedObject private var languageManager = LanguageManager.shared

    var chartData: [IncomeExpenseData] {
        let calendar = Calendar.current
        let now = Date()

        // Last 6 months
        let months = (0..<6).compactMap { offset -> Date? in
            calendar.date(byAdding: .month, value: -offset, to: now)
        }.reversed()

        return months.compactMap { date -> IncomeExpenseData? in
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                return nil
            }

            let monthTransactions = transactions.filter { $0.date >= monthStart && $0.date < monthEnd }

            let income = monthTransactions.reduce(0.0) { result, trans in
                result + (trans.type == .income ? Double(truncating: trans.amount as NSNumber) : 0)
            }

            let expense = monthTransactions.reduce(0.0) { result, trans in
                result + (trans.type == .expense ? Double(truncating: trans.amount as NSNumber) : 0)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = languageManager.locale

            return IncomeExpenseData(
                period: formatter.string(from: date),
                income: income,
                expense: expense,
                date: date
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Income vs Expenses".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let selected = selectedPeriod {
                        HStack(spacing: 12) {
                            Label(Decimal(selected.income).coinFormatted, systemImage: "arrow.down")
                                .font(.caption)
                                .foregroundColor(.green)
                            Label(Decimal(selected.expense).coinFormatted, systemImage: "arrow.up")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    } else {
                        Text("Last 6 months".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Income".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Expense".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if chartData.allSatisfy({ $0.income == 0 && $0.expense == 0 }) {
                emptyStateView
            } else {
                Chart(chartData) { item in
                    BarMark(
                        x: .value("Period", item.period),
                        y: .value("Income", item.income)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.9),
                                Color.green.opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)

                    BarMark(
                        x: .value("Period", item.period),
                        y: .value("Expense", item.expense)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.9),
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.7)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)

                    if let selected = selectedPeriod, selected.id == item.id {
                        RuleMark(x: .value("Period", item.period))
                            .foregroundStyle(.gray.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                        Text(Decimal(item.income).coinFormatted)
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(red: 0.2, green: 0.8, blue: 0.6))
                                            .frame(width: 6, height: 6)
                                        Text(Decimal(item.expense).coinFormatted)
                                            .font(.caption)
                                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                                    }
                                    let net = item.income - item.expense
                                    HStack(spacing: 8) {
                                        Image(systemName: net >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(net >= 0 ? .green : .red)
                                        Text("Net: \(Decimal(abs(net)).coinFormatted)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisValueLabel {
                            if let stringValue = value.as(String.self) {
                                Text(stringValue)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, value: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(Decimal(doubleValue).shortCoinFormatted)
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(height: 200)
                .padding(.trailing, 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No transaction data available".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
}
