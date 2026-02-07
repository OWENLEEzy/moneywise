import SwiftUI
import Charts

// MARK: - Monthly Spending Trend Chart (Line Chart)

struct MonthlySpendingTrendChart: View {
    let transactions: [Transaction]
    @State private var selectedMonth: MonthlySpendingData?
    @ObservedObject private var languageManager = LanguageManager.shared

    var chartData: [MonthlySpendingData] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction -> Date in
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            return calendar.date(from: components) ?? transaction.date
        }

        return grouped.map { (date, trans) in
            let total = trans.reduce(0.0) { result, trans in
                result + (trans.type == .expense ? Double(truncating: trans.amount as NSNumber) : 0)
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            formatter.locale = languageManager.locale
            return MonthlySpendingData(month: formatter.string(from: date), amount: total, date: date)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Spending Trend".localized)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let selected = selectedMonth {
                        Text("\(selected.month): \(Decimal(selected.amount).coinFormatted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            if chartData.isEmpty || chartData.allSatisfy({ $0.amount == 0 }) {
                emptyStateView
            } else {
                Chart(chartData) { item in
                    LineMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.6),
                                Color(red: 0.1, green: 0.6, blue: 0.5)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", item.month),
                        y: .value("Amount", item.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3),
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.05)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    if let selected = selectedMonth, selected.id == item.id {
                        PointMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .annotation(position: .top) {
                            Text(Decimal(item.amount).coinFormatted)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .chartAngleSelection(value: $selectedMonth.map { $0.id })
                .chartBackground { chartProxy in
                    GeometryReader { geometry in
                        if let selectedMonth,
                           let plotFrame = chartProxy.plotFrame {
                            let xPos = chartProxy.position(forX: selectedMonth.month) ?? 0
                            if xPos >= plotFrame.minX && xPos <= plotFrame.maxX {
                                VStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 1, height: plotFrame.height)
                                        .position(x: xPos, y: plotFrame.midY)
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let selected = findMonth(at: value.location.x) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    self.selectedMonth = selected
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.selectedMonth = nil
                            }
                        }
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.flattrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No spending data available".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }

    private func findMonth(at xPosition: CGFloat) -> MonthlySpendingData? {
        guard let chartWidth = chartData.first.map({ _ in CGFloat(chartData.count * 50) }) else {
            return nil
        }
        let index = Int(xPosition / 50)
        return chartData.indices.contains(index) ? chartData[index] : nil
    }
}

// MARK: - Weekly Spending Trend Chart (for Visual Analysis section)

struct WeeklySpendingTrendChart: View {
    let transactions: [Transaction]
    let period: TrendPeriod
    @State private var selectedDay: DailySpendingData?
    @ObservedObject private var languageManager = LanguageManager.shared

    enum TrendPeriod {
        case weekly
        case monthly

        var days: Int {
            switch self {
            case .weekly: return 7
            case .monthly: return 30
            }
        }
    }

    var chartData: [DailySpendingData] {
        let calendar = Calendar.current
        let now = Date()
        let days = (0..<period.days).compactMap { offset -> Date? in
            calendar.date(byAdding: .day, value: -offset, to: now)
        }.reversed()

        return days.map { date in
            let dayTransactions = transactions.filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            let total = dayTransactions.reduce(0.0) { result, trans in
                result + (trans.type == .expense ? Double(truncating: trans.amount as NSNumber) : 0)
            }

            let formatter = DateFormatter()
            formatter.dateFormat = period == .weekly ? "E" : "d MMM"
            formatter.locale = languageManager.locale

            return DailySpendingData(
                day: formatter.string(from: date),
                value: total,
                date: date
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spending Trend".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let selected = selectedDay {
                    Text(Decimal(selected.value).coinFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if chartData.allSatisfy({ $0.value == 0 }) {
                emptyStateView
            } else {
                Chart(chartData) { item in
                    LineMark(
                        x: .value("Date", item.day),
                        y: .value("Expense", item.value)
                    )
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", item.day),
                        y: .value("Expense", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.25),
                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.02)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    if let selected = selectedDay, selected.id == item.id {
                        PointMark(
                            x: .value("Date", item.day),
                            y: .value("Expense", item.value)
                        )
                        .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.6))
                        .annotation(position: .top) {
                            Text(Decimal(item.value).coinFormatted)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(position: .bottom, value: .automatic(desiredCount: period == .weekly ? 7 : 10)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis(.hidden)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No spending data".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
}
