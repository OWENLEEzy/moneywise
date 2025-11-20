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
            .navigationTitle("AI Assistant")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction Confirmation Card")
                .font(.headline)
            
            Text(transaction.amount, format: .currency(code: "CNY"))
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Category: \(transaction.category?.name ?? "N/A")")
                Text("Account: \(transaction.account)")
                Text("Time: \(transaction.date.formatted())")
            }
            
            HStack {
                Button("Confirm") {
                    viewModel.confirmTransaction(context: context)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Edit") {
                    // TODO: Implement edit functionality
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.green.opacity(0.2))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
