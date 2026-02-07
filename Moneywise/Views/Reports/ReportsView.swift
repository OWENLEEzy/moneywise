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
    
    @State private var selectedVisualPeriod: VisualPeriod = .thisMonth
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showingAIChatSheet = false
    @State private var refreshTrigger = 0
    @ObservedObject private var languageManager = LanguageManager.shared
    
    enum VisualPeriod: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        
        var localizedName: String {
            return self.rawValue.localized
        }
    }
    
    var currentInsight: AIInsight? {
        // Force refresh trigger
        _ = refreshTrigger
        // AI Analysis always uses monthly data
        let result = insights.first { $0.type == .monthly }
        return result
    }
    
    var filteredTransactionsForVisual: [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return transactions.filter { transaction in
            if selectedVisualPeriod == .thisWeek {
                guard let weekStart = calendar.date(byAdding: .day, value: -7, to: now) else {
                    return false
                }
                return transaction.date >= weekStart
            } else {
                guard let monthComponents = calendar.dateComponents([.year, .month], from: now),
                      let monthStart = calendar.date(from: monthComponents) else {
                    return false
                }
                return transaction.date >= monthStart
            }
        }
    }

    var monthlyTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthComponents = calendar.dateComponents([.year, .month], from: now),
              let monthStart = calendar.date(from: monthComponents) else {
            return []  // Return empty array if date calculation fails
        }
        return transactions.filter { $0.date >= monthStart }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // AI Analysis Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("AI Analysis".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                            if !monthlyTransactions.isEmpty, currentInsight != nil {
                                Button(action: { 
                                    generateInsights()
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Refresh".localized)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.2, green: 0.8, blue: 0.6))
                                    .cornerRadius(8)
                                }
                                .disabled(isGenerating)
                                .opacity(isGenerating ? 0.6 : 1.0)
                            }
                        }
                        
                        if monthlyTransactions.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "brain")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("AI currently doesn't have enough data".localized)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Start adding transactions to see insights here.".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        } else {
                            if let insight = currentInsight {
                                // Loading overlay during refresh
                                ZStack {
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Summary Card
                                        VStack(alignment: .leading, spacing: 12) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Monthly Summary".localized)
                                                        .font(.headline)
                                                        .foregroundColor(.primary)
                                                    
                                                    Text("Updated: \(insight.generatedAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: LanguageManager.shared.locale)))")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                            }
                                            
                                            Divider()
                                            
                                            Text(insight.summary)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                                .lineSpacing(4)
                                        }
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.orange.opacity(0.15),
                                                    Color.orange.opacity(0.08)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                        
                                        // Insights
                                        if !insight.consumptionInsights.isEmpty {
                                            VStack(alignment: .leading, spacing: 12) {
                                                Text("Key Insights".localized)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                ForEach(insight.consumptionInsights, id: \.self) { item in
                                                    HStack(alignment: .top, spacing: 12) {
                                                        Image(systemName: "lightbulb.fill")
                                                            .foregroundColor(.yellow)
                                                            .font(.system(size: 16))
                                                            .padding(.top, 2)
                                                        Text(item)
                                                            .font(.subheadline)
                                                            .foregroundColor(.primary)
                                                            .lineSpacing(2)
                                                    }
                                                    .padding()
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(Color(UIColor.systemBackground))
                                                    .cornerRadius(10)
                                                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                                                }
                                            }
                                        }
                                    }
                                    .blur(radius: isGenerating ? 3 : 0)
                                    .disabled(isGenerating)
                                    
                                    // Loading overlay
                                    if isGenerating {
                                        VStack(spacing: 16) {
                                            ProgressView()
                                                .scaleEffect(1.5)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            Text("Analyzing your transactions...".localized)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color(UIColor.systemBackground).opacity(0.8))
                                        .cornerRadius(12)
                                    }
                                }
                            } else {
                                // Initial generation button
                                Button(action: {
                                    generateInsights()
                                }) {
                                    HStack(spacing: 8) {
                                        if isGenerating {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 16))
                                        }
                                        Text(isGenerating ? "Analyzing...".localized : "Generate AI Insights".localized)
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(red: 0.2, green: 0.8, blue: 0.6),
                                                Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.8)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(10)
                                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                                .padding(.horizontal, 40) // Add horizontal padding to shrink width visually
                                .disabled(isGenerating)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Visual Analysis Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Visual analysis".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        // Time Period Selector
                        Picker("Period".localized, selection: $selectedVisualPeriod) {
                            ForEach(VisualPeriod.allCases, id: \.self) { period in
                                Text(period.localizedName).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if filteredTransactionsForVisual.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No data for this period".localized)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        } else {
                            // Weekly/Monthly Spending Trend
                            WeeklySpendingTrendChart(
                                transactions: filteredTransactionsForVisual,
                                period: selectedVisualPeriod == .thisWeek ? .weekly : .monthly
                            )

                            // Category Spending Donut Chart
                            CategorySpendingDonutChart(
                                transactions: filteredTransactionsForVisual
                            )
                        }
                    }

                    Divider()
                        .padding(.vertical, 8)

                    // Overview Charts Section (All-time data)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Overview".localized)
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }

                        // Monthly Spending Trend (All-time)
                        MonthlySpendingTrendChart(transactions: transactions)

                        // Income vs Expense Bar Chart (Last 6 months)
                        IncomeExpenseBarChart(transactions: transactions)
                    }
                }
                .padding()
            }
            .navigationTitle("Reports".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedTab = .home
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back".localized)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAIChatSheet = true
                    }) {
                        Image(systemName: "message.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAIChatSheet) {
                ReportAIChatView()
            }
            .alert("Error".localized, isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }
    
    private func generateInsights() {
        guard !isGenerating, !monthlyTransactions.isEmpty else { 
            return 
        }
        
        isGenerating = true
        Task { @MainActor in
            do {
                let aiService = AIService(apiKeyProvider: {
                    KeychainService().value(for: .geminiAPIKey)
                })
                
                let result = try await aiService.generateInsights(
                    transactions: monthlyTransactions,
                    period: "current month",
                    context: context
                )
                
                // Delete old insight
                if let oldInsight = currentInsight {
                    context.delete(oldInsight)
                    context.saveSafe()
                }

                let newInsight = AIInsight(
                    type: .monthly,
                    startDate: Date(),
                    endDate: Date(),
                    summary: result.summary,
                    consumptionInsights: result.insights
                )
                context.insert(newInsight)
                context.saveSafe()
                
                // Force UI refresh
                refreshTrigger += 1
                
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
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("AI Report Assistant".localized)
                    .font(.headline)
                Spacer()
                Button("Done".localized) {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(chatViewModel.messages) { msg in
                        MessageBubble(message: msg)
                    }
                    
                    if chatViewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("AI analyzing...".localized)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                TextField("Ask about your spending...".localized, text: $inputText)
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