import SwiftUI
import Charts

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MonthlySummaryCard()
                    SpendingTrendChart()
                    InsightCards()
                }
                .padding()
            }
            .navigationTitle("Monthly Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MonthlySummaryCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Conclusion (AI Summary)")
                .font(.headline)
            Text("This month your Engel coefficient is bit high, with food delivery increasing by 30% compared with last month. How about trying to cook next week.")
                .font(.subheadline)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SpendingTrendChart: View {
    let data: [SpendingData] = [
        .init(day: "Wodan", value: 30),
        .init(day: "Wosdem", value: 10),
        .init(day: "Toui", value: 40),
        .init(day: "Tiada", value: 20),
        .init(day: "Touth", value: 35)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Spending Trend")
                .font(.headline)
            
            HStack {
                Text("Top 3 Categories")
                Spacer()
                Image(systemName: "fuelpump.fill")
                Image(systemName: "fork.knife")
                Image(systemName: "bag.fill")
            }
            .padding(.bottom, 8)
            
            Chart(data) {
                LineMark(
                    x: .value("Day", $0.day),
                    y: .value("Spending", $0.value)
                )
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct SpendingData: Identifiable {
    let id = UUID()
    let day: String
    let value: Int
}

struct InsightCards: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Insight Cards")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("You typically spend the most on Friday evenings.")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                
                VStack(alignment: .leading) {
                    Text("You spent ¥120 on subscription services this month (e.g., video streaming)")
                        .font(.subheadline)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }
}
