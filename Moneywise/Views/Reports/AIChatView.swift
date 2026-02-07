// AIChatView.swift
import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(\.modelContext) private var context
    @State private var showingHistory = false

    private let aiService: AIService
    
    init() {
        self.aiService = AIService(apiKeyProvider: {
            KeychainService().value(for: .geminiAPIKey)
        })
    }
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var conversationId: String?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            List {
                ForEach(messages) { message in
                    HStack {
                        if message.isUser {
                            Spacer()
                            Text(message.content)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        } else {
                            Text(message.content)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                            Spacer()
                        }
                    }
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            
            if isProcessing {
                ProgressView()
                    .padding()
            }
            
            HStack {
                TextField("Ask about your finances...".localized, text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding()
        }
        .navigationTitle("AI Assistant".localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showingHistory) {
            ConversationHistoryView()
        }
        .alert("Error".localized, isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK".localized, role: .cancel) { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        let query = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            do {
                let (response, newId) = try await aiService.chat(message: query, conversationId: conversationId, context: context)
                conversationId = newId
                let aiMessage = ChatMessage(content: response, isUser: false)
                messages.append(aiMessage)
                
                // Keep only last 10 messages
                if messages.count > 10 {
                    messages.removeFirst(messages.count - 10)
                }
            } catch {
                errorMessage = "Chat failed: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}


