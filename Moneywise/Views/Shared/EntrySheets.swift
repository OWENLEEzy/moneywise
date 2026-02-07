import SwiftUI
import SwiftData
import Combine

struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var categories: [SpendingCategory]
    
    @Binding var toastMessage: String?
    var transactionToEdit: Transaction?
    
    @State private var amount: Decimal = 0
    @State private var type: TransactionType = .expense
    @State private var category: SpendingCategory?
    @State private var account: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Transaction Details".localized)) {
                    TextField("Amount".localized, value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Type".localized, selection: $type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    
                    Picker("Category".localized, selection: $category) {
                        ForEach(categories) { category in
                            HStack {
                                Text(category.icon)
                                Text(category.name)
                            }
                            .tag(category as SpendingCategory?)
                        }
                    }
                    
                    TextField("Account".localized, text: $account)
                    DatePicker("Date".localized, selection: $date, displayedComponents: .date)
                    TextField("Note".localized, text: $note)
                }
            }
            .navigationTitle(transactionToEdit == nil ? "Manual Entry".localized : "Edit Transaction".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(transactionToEdit == nil ? "New Transaction".localized : "Save Changes".localized) {
                        saveTransaction()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let transaction = transactionToEdit {
                    amount = transaction.amount
                    type = transaction.type
                    category = transaction.category
                    account = transaction.account
                    date = transaction.date
                    note = transaction.note
                }
            }
        }
    }
    
    private func saveTransaction() {
        if let transaction = transactionToEdit {
            // Update existing
            transaction.amount = amount
            transaction.type = type
            transaction.category = category
            transaction.account = account
            transaction.date = date
            transaction.note = note
            toastMessage = "Transaction Updated".localized
        } else {
            // Create new
            let newTransaction = Transaction(amount: amount, type: type, category: category, account: account, date: date, note: note)
            context.insert(newTransaction)
            toastMessage = "Transaction Saved".localized
        }
    }
}

@MainActor
class AISmartEntryViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var conversation: [Message] = []
    @Published var parsedTransaction: Transaction?
    @Published var isThinking: Bool = false
    @Published var errorMessage: String?
    
    private let aiService: AIService
    
    init(aiService: AIService) {
        self.aiService = aiService
        self.conversation.append(Message(content: "Welcome! How can I help you?".localized, isUser: false))
    }
    
    func sendMessage(context: ModelContext) async {
        let userMessage = Message(content: inputText, isUser: true)
        conversation.append(userMessage)
        let textToProcess = inputText
        inputText = ""
        isThinking = true
        errorMessage = nil
        
        do {
            let parsed = try await aiService.parse(text: textToProcess, context: context)
            self.parsedTransaction = parsed
            self.conversation.append(Message(content: "I've parsed your transaction. Please confirm:".localized, isUser: false))
        } catch let error as AIServiceError {
            let errorMsg = "Sorry, I couldn't understand that. Error: \(error.localizedDescription)"
            self.conversation.append(Message(content: errorMsg, isUser: false))
            self.errorMessage = error.localizedDescription
        } catch {
            let errorMsg = "Sorry, I couldn't understand that. Error: \(error.localizedDescription)"
            self.conversation.append(Message(content: errorMsg, isUser: false))
            self.errorMessage = error.localizedDescription
        }
        isThinking = false
    }
    
    func confirmTransaction(context: ModelContext) {
        if let transaction = parsedTransaction {
            context.insert(transaction)
            conversation.append(Message(content: "Transaction saved!".localized, isUser: false))
            parsedTransaction = nil
        }
    }
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

struct AISmartEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @StateObject private var viewModel: AISmartEntryViewModel
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var showingSpeechPermissionAlert = false
    @State private var showingManualEntry = false
    @State private var transactionToEdit: Transaction?
    
    @Binding var toastMessage: String?
    
    init(toastMessage: Binding<String?>) {
        _toastMessage = toastMessage
        
        let aiService = AIService(apiKeyProvider: {
            KeychainService().value(for: .geminiAPIKey)
        })
        _viewModel = StateObject(wrappedValue: AISmartEntryViewModel(aiService: aiService))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.conversation) { message in
                            MessageView(message: message)
                        }
                        if viewModel.isThinking {
                            ProgressView()
                                .padding()
                        }
                        if let transaction = viewModel.parsedTransaction {
                            TransactionConfirmationCard(transaction: transaction, viewModel: viewModel, onEdit: {
                                transactionToEdit = transaction
                                showingManualEntry = true
                            })
                        }
                    }
                }
                
                HStack {
                    TextField("Just bought a bento box...".localized, text: $viewModel.inputText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: speechService.transcribedText) { oldValue, newValue in
                            if !newValue.isEmpty {
                                viewModel.inputText = newValue
                            }
                        }
                    
                    Button(action: {
                        Task {
                            if speechService.isRecording {
                                speechService.stopRecording()
                            } else {
                                let authorized = await speechService.requestAuthorization()
                                if authorized {
                                    do {
                                        try await speechService.startRecording()
                                    } catch {
                                        speechService.errorMessage = error.localizedDescription
                                    }
                                } else {
                                    showingSpeechPermissionAlert = true
                                }
                            }
                        }
                    }) {
                        Image(systemName: speechService.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(speechService.isRecording ? Color(red: 0.95, green: 0.4, blue: 0.4) : Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.sendMessage(context: context)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                    .disabled(viewModel.inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("AI Recording".localized)
            .navigationBarTitleDisplayMode(.inline)
            .alert("Microphone Permission Required".localized, isPresented: $showingSpeechPermissionAlert) {
                Button("OK".localized, role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to use voice features.".localized)
            }
            .alert("AI Error".localized, isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK".localized, role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        transactionToEdit = nil
                        showingManualEntry = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntrySheet(toastMessage: $toastMessage, transactionToEdit: transactionToEdit)
                    .presentationDetents([.large])
            }
        }
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(12)
            } else {
                Text(message.content)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                Spacer()
            }
        }
        .padding(.horizontal)
    }
}

struct TransactionConfirmationCard: View {
    let transaction: Transaction
    @ObservedObject var viewModel: AISmartEntryViewModel
    var onEdit: () -> Void
    @Environment(\.modelContext) private var context
    
    @State private var countdown: Int = 3
    @State private var timer: Timer?
    @State private var autoConfirmEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Transaction".localized)
                .font(.headline)
            
            // Amount
            Text(transaction.amount.coinFormatted)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Category:".localized)
                        .foregroundColor(.secondary)
                    Text(transaction.category?.name ?? "Uncategorized".localized)
                }
                HStack {
                    Text("Account:".localized)
                        .foregroundColor(.secondary)
                    Text(transaction.account)
                }
                HStack {
                    Text("Time:".localized)
                        .foregroundColor(.secondary)
                    Text(transaction.date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: LanguageManager.shared.locale)))
                }
                HStack {
                    Text("Note:".localized)
                        .foregroundColor(.secondary)
                    Text(transaction.note)
                }
            }
            .font(.callout)
            
            // Auto-confirm countdown
            if autoConfirmEnabled && transaction.confidence >= 0.8 {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text(String(format: "Auto-confirming in %ds".localized, countdown))
                            .foregroundColor(.orange)
                            .font(.subheadline)
                    }
                    
                    ProgressView(value: Double(3 - countdown), total: 3.0)
                        .tint(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else if transaction.confidence < 0.8 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    // Low confidence, please confirm manually
                        .foregroundColor(.yellow)
                    Text("Low confidence, please check details".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Buttons
            HStack(spacing: 12) {
                Button(action: {
                    stopTimer()
                    viewModel.confirmTransaction(context: context)
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                if autoConfirmEnabled {
                    Button(action: {
                        stopTimer()
                        autoConfirmEnabled = false
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Cancel Timer".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        onEdit()
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 5)
        .onAppear {
            if transaction.confidence >= 0.8 {
                startCountdown()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startCountdown() {
        autoConfirmEnabled = true
        countdown = 3
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if countdown > 0 {
                    countdown -= 1
                } else {
                    stopTimer()
                    viewModel.confirmTransaction(context: context)
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
