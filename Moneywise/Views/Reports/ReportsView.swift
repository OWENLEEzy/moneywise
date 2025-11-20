import SwiftUI
import Charts
import SwiftData
import Combine

struct ReportsView: View {
    @Binding var selectedTab: ContentView.Tab
    @Environment(\.modelContext) private var context
    @Environment(\.presentationMode) var presentationMode
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \AIInsight.generatedAt, order: .reverse) private var insights: [AIInsight]
    
    @State private var showingAIChat = false
    @State private var selectedPeriod: AIInsight.InsightType = .monthly
    @State private var isGenerating = false
    @State private var errorMessage: String?
    
    var currentInsight: AIInsight? {
        insights.first { $0.type == selectedPeriod }
    }
    
    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            if selectedPeriod == .weekly {
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                return transaction.date >= weekStart
            } else {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return transaction.date >= monthStart
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        Text("This Month").tag(AIInsight.InsightType.monthly)
                        Text("This Week").tag(AIInsight.InsightType.weekly)
                    }
                    .pickerStyle(.segmented)
                    
                    if filteredTransactions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("AI currently doesn't have enough data")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Start adding transactions to see insights here.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    } else {
                        // AI Summary Card
                        if let insight = currentInsight {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(selectedPeriod == .monthly ? "Monthly Summary" : "Weekly Summary")
                                        .font(.headline)
                                    Spacer()
                                    if isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Button(action: generateInsights) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption)
                                        }
                                    }
                                }
                                
                                Text(insight.summary)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text("Last updated: \(insight.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            Button(action: generateInsights) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .padding(.trailing, 8)
                                    }
                                    Text(isGenerating ? "Analyzing..." : "Generate AI Insights")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .disabled(isGenerating)
                        }
                        
                        SpendingTrendChart(transactions: filteredTransactions, period: selectedPeriod)
                        
                        // Insights
                        if let insight = currentInsight, !insight.consumptionInsights.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Consumption Insights")
                                    .font(.headline)
                                
                                ForEach(insight.consumptionInsights, id: \.self) { item in
                                    HStack(alignment: .top) {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                            .padding(.top, 4)
                                        Text(item)
                                            .font(.subheadline)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .home
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAIChat = true
                    }) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAIChat) {
                ReportAIChatView()
            }
            .onChange(of: selectedPeriod) { _, _ in
                // Auto-generate if no insight exists for this period and we have data
                if currentInsight == nil && !filteredTransactions.isEmpty {
                    generateInsights()
                }
            }
        }
    }
    
    private func generateInsights() {
        guard !isGenerating, !filteredTransactions.isEmpty else { return }
        
        isGenerating = true
        Task {
            do {
                let aiService = AIService(apiKeyProvider: {
                    KeychainService().value(for: .geminiAPIKey)
                })
                
                let periodName = selectedPeriod == .monthly ? "current month" : "last 7 days"
                let result = try await aiService.generateInsights(
                    transactions: filteredTransactions,
                    period: periodName,
                    context: context
                )
                
                // Delete old insight for this period
                if let oldInsight = currentInsight {
                    context.delete(oldInsight)
                }
                
                let newInsight = AIInsight(
                    type: selectedPeriod,
                    startDate: Date(), // Simplified for now
                    endDate: Date(),
                    summary: result.summary,
                    consumptionInsights: result.insights
                )
                context.insert(newInsight)
                
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

struct ReportAIChatView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @StateObject private var chatViewModel = ReportChatViewModel()
    @State private var inputText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(chatViewModel.messages) { msg in
                            MessageBubble(message: msg)
                        }
                        
                        if chatViewModel.isLoading {
                            HStack {
                                ProgressView()
                                Text("AI analyzing...")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                
                HStack {
                    TextField("Ask about your spending...", text: $inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            await chatViewModel.askQuestion(inputText, context: context)
                            inputText = ""
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                    }
                    .disabled(inputText.isEmpty || chatViewModel.isLoading)
                }
                .padding()
            }
            .navigationTitle("AI Report Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding()
                .background(message.isUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(12)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

@MainActor
class ReportChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    func askQuestion(_ question: String, context: ModelContext) async {
        let userMessage = ChatMessage(content: question, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let transactions = try context.fetch(FetchDescriptor<Transaction>())
            let reportData = generateReportData(from: transactions)
            
            let aiService = AIService(apiKeyProvider: {
                KeychainService().value(for: .geminiAPIKey)
            })
            
            let answer = try await aiService.analyze(question: question + "\n\nReport Data:\n" + reportData, context: context)
            
            let aiMessage = ChatMessage(content: answer, isUser: false)
            messages.append(aiMessage)
        } catch {
            let errorMessage = ChatMessage(content: "Sorry, analysis failed: \(error.localizedDescription)", isUser: false)
            messages.append(errorMessage)
        }
    }
    
    private func generateReportData(from transactions: [Transaction]) -> String {
        let grouped = Dictionary(grouping: transactions) { transaction -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            return formatter.string(from: transaction.date)
        }
        
        var report = "# Billing Statistics\n\n"
        for (month, trans) in grouped.sorted(by: { $0.key > $1.key }) {
            let total = trans.reduce(Decimal(0)) { $0 + ($1.type == .expense ? $1.amount : 0) }
            report += "## \(month)\n"
            report += "Total Expense: 🪙 \(total)\n"
            report += "Transactions: \(trans.count) items\n\n"
        }
        
        return report
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

struct SpendingTrendChart: View {
    let transactions: [Transaction]
    let period: AIInsight.InsightType
    
    var chartData: [SpendingData] {
        let calendar = Calendar.current
        let now = Date()
        let dates: [Date]
        
        if period == .weekly {
            dates = (0..<7).map { calendar.date(byAdding: .day, value: -$0, to: now)! }.reversed()
        } else {
            // Last 30 days for monthly view
            dates = (0..<30).map { calendar.date(byAdding: .day, value: -$0, to: now)! }.reversed()
        }
        
        return dates.map { date in
            let dayTransactions = transactions.filter {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            let total = dayTransactions.reduce(0.0) { result, trans in
                result + (trans.type == .expense ? Double(truncating: trans.amount as NSNumber) : 0)
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = period == .weekly ? "E" : "d"
            formatter.locale = Locale(identifier: "en_US")
            
            return SpendingData(day: formatter.string(from: date), value: total)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Spending Trend")
                .font(.headline)
            
            if chartData.allSatisfy({ $0.value == 0 }) {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(chartData) {
                    LineMark(
                        x: .value("Date", $0.day),
                        y: .value("Expense", $0.value)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct SpendingData: Identifiable {
    let id = UUID()
    let day: String
    let value: Double
}

