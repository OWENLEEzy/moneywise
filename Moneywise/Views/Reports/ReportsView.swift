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
        print("🔍 [DEBUG] currentInsight computed - insights.count: \(insights.count)")
        if !insights.isEmpty {
            print("🔍 [DEBUG] All insights types: \(insights.map { $0.type })")
        }
        // AI Analysis always uses monthly data
        let result = insights.first { $0.type == .monthly }
        print("🔍 [DEBUG] Found monthly insight: \(result != nil)")
        return result
    }
    
    var filteredTransactionsForVisual: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        
        return transactions.filter { transaction in
            if selectedVisualPeriod == .thisWeek {
                let weekStart = calendar.date(byAdding: .day, value: -7, to: now)!
                return transaction.date >= weekStart
            } else {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return transaction.date >= monthStart
            }
        }
    }
    
    var monthlyTransactions: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
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
                                    print("🟢 [BUTTON] Refresh button pressed")
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
                                    print("🟢 [BUTTON] Generate AI Insights button pressed")
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
                            SpendingTrendChart(
                                transactions: filteredTransactionsForVisual,
                                period: selectedVisualPeriod == .thisWeek ? .weekly : .monthly
                            )
                            
                            ExpenseRatioPieChart(
                                transactions: filteredTransactionsForVisual
                            )
                        }
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
        print("🔵 [DEBUG] generateInsights called")
        print("🔵 [DEBUG] isGenerating: \(isGenerating)")
        print("🔵 [DEBUG] monthlyTransactions count: \(monthlyTransactions.count)")
        
        guard !isGenerating, !monthlyTransactions.isEmpty else { 
            print("❌ [DEBUG] Guard failed - isGenerating: \(isGenerating), isEmpty: \(monthlyTransactions.isEmpty)")
            return 
        }
        
        print("✅ [DEBUG] Starting insight generation...")
        isGenerating = true
        Task { @MainActor in
            do {
                print("🔵 [DEBUG] Creating AIService...")
                let aiService = AIService(apiKeyProvider: {
                    let key = KeychainService().value(for: .geminiAPIKey)
                    print("🔵 [DEBUG] API Key exists: \(key != nil)")
                    return key
                })
                
                print("🔵 [DEBUG] Calling aiService.generateInsights...")
                let result = try await aiService.generateInsights(
                    transactions: monthlyTransactions,
                    period: "current month",
                    context: context
                )
                
                print("✅ [DEBUG] Got insights result - summary: \(result.summary)")
                
                // Delete old insight
                if let oldInsight = currentInsight {
                    print("🔵 [DEBUG] Deleting old insight")
                    context.delete(oldInsight)
                    try? context.save()
                }
                
                let newInsight = AIInsight(
                    type: .monthly,
                    startDate: Date(), // Simplified for now
                    endDate: Date(),
                    summary: result.summary,
                    consumptionInsights: result.insights
                )
                context.insert(newInsight)
                try context.save()
                
                // Force UI refresh
                refreshTrigger += 1
                
                print("✅ [DEBUG] New insight saved to context")
                print("🔵 [DEBUG] Current insights count: \(insights.count)")
                print("🔵 [DEBUG] Refresh trigger: \(refreshTrigger)")
                
            } catch {
                print("❌ [DEBUG] Error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            isGenerating = false
            print("🔵 [DEBUG] generateInsights completed - isGenerating: \(isGenerating)")
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
            formatter.locale = LanguageManager.shared.locale
            
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
                    .foregroundStyle(Color(red: 0.2, green: 0.8, blue: 0.6))
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

struct ExpenseRatioPieChart: View {
    let transactions: [Transaction]
    
    struct CategoryData: Identifiable {
        let id = UUID()
        let name: String
        let amount: Double
        let color: Color
    }
    
    var chartData: [CategoryData] {
        let expenses = transactions.filter { $0.type == .expense }
        let totalExpense = expenses.reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }
        
        guard totalExpense > 0 else { return [] }
        
        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }
        
        let sortedCategories = grouped.map { (key, value) -> (String, Double) in
            let categoryTotal = value.reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }
            return (key, categoryTotal)
        }.sorted { $0.1 > $1.1 }
        
        // Base color: Cyan-Green (App Theme)
        // Color(red: 0.2, green: 0.8, blue: 0.6)
        // We will adjust opacity/brightness based on rank or percentage
        
        return sortedCategories.enumerated().map { index, item in
            // Calculate opacity based on value relative to total (or just rank for distinctness)
            // Strategy: Darker for larger values.
            // Max opacity 1.0, Min opacity 0.3

            // Using opacity is simple but might overlap. Using saturation/brightness is better.
            // Let's use the base color and adjust opacity for the "monochromatic" feel requested.
            // "占比越多颜色越深" -> Higher ratio = Higher Opacity/Saturation
            
            let opacity = 0.3 + (0.7 * (item.1 / sortedCategories[0].1)) // Relative to largest item
            
            return CategoryData(
                name: item.0,
                amount: item.1,
                color: Color(red: 0.2, green: 0.8, blue: 0.6).opacity(opacity)
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expense Ratio")
                .font(.headline)
            
            if chartData.isEmpty {
                Text("No expense data available")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .center, spacing: 20) {
                    // Pie Chart
                    Chart(chartData) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 200, height: 200)
                    .padding(.vertical, 12)
                    
                    // Legend
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(chartData) { item in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 10, height: 10)
                                    
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(item.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Text(Decimal(item.amount).coinFormatted)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.vertical, 12)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}
