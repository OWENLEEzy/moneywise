import SwiftUI
import SwiftData
import Combine

struct ManualEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Binding var toastMessage: String?
    
    @State private var amount: Decimal = 0
    @State private var type: TransactionType = .expense
    @State private var category: SpendingCategory?
    @State private var account: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Transaction Details")) {
                    TextField("Amount", value: $amount, format: .number)
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                    // TODO: Category picker
                    TextField("Account", text: $account)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note", text: $note)
                }
            }
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveTransaction() {
        let newTransaction = Transaction(amount: amount, type: type, category: category, account: account, date: date, note: note)
        context.insert(newTransaction)
        toastMessage = "Transaction Saved"
    }
}

@MainActor
class AISmartEntryViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var conversation: [Message] = []
    @Published var parsedTransaction: Transaction?
    @Published var isThinking: Bool = false
    
    private let aiService: AIService
    
    init(aiService: AIService) {
        self.aiService = aiService
        self.conversation.append(Message(content: "Welcome! How can I help you?", isUser: false))
    }
    
    func sendMessage(context: ModelContext) async {
        let userMessage = Message(content: inputText, isUser: true)
        conversation.append(userMessage)
        let textToProcess = inputText
        inputText = ""
        isThinking = true
        
        do {
            let parsed = try await aiService.parse(text: textToProcess, context: context)
            self.parsedTransaction = parsed
        } catch {
            self.conversation.append(Message(content: "Sorry, I couldn't understand that. Please try again.", isUser: false))
        }
        isThinking = false
    }
    
    func confirmTransaction(context: ModelContext) {
        if let transaction = parsedTransaction {
            context.insert(transaction)
            conversation.append(Message(content: "Transaction saved!", isUser: false))
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
                            TransactionConfirmationCard(transaction: transaction, viewModel: viewModel)
                        }
                    }
                }
                
                HStack {
                    TextField("Just bought a bento box...", text: $viewModel.inputText)
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
                            .foregroundColor(speechService.isRecording ? .red : .blue)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.sendMessage(context: context)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                    }
                    .disabled(viewModel.inputText.isEmpty)
                }
                .padding()
            }
            .navigationTitle("AI Recording")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Microphone Permission Required", isPresented: $showingSpeechPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enable microphone access in Settings to use voice features.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
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
    @Environment(\.modelContext) private var context
    
    @State private var countdown: Int = 3
    @State private var timer: Timer?
    @State private var autoConfirmEnabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm Transaction")
                .font(.headline)
            
            // Amount
            Text(transaction.amount.coinFormatted)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Category:")
                        .foregroundColor(.secondary)
                    Text(transaction.category?.name ?? "Uncategorized")
                }
                HStack {
                    Text("Account:")
                        .foregroundColor(.secondary)
                    Text(transaction.account)
                }
                HStack {
                    Text("Time:")
                        .foregroundColor(.secondary)
                    Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                }
                HStack {
                    Text("Note:")
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
                        Text("Auto-confirming in \(countdown)s")
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
                    Text("Low confidence, please check details")
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
                        Text("Confirm")
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
                            Text("Cancel Timer")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: {
                        // TODO: Implement edit functionality
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit")
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
            if countdown > 0 {
                countdown -= 1
            } else {
                stopTimer()
                viewModel.confirmTransaction(context: context)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
