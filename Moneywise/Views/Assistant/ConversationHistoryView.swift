// ConversationHistoryView.swift
import SwiftUI
import SwiftData

struct ConversationHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let aiService: AIService

    @Query(sort: \AIConversation.updatedAt, order: .reverse)
    private var conversations: [AIConversation]

    @State private var errorMessage: String?

    init() {
        self.aiService = AIService(apiKeyProvider: {
            KeychainService().value(for: .geminiAPIKey)
        })
    }

    var body: some View {
        NavigationStack {
            List {
                if conversations.isEmpty {
                    ContentUnavailableView {
                        Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                    } description: {
                        Text("Start a chat with AI assistant to see your conversation history here.")
                    }
                } else {
                    ForEach(conversations) { conversation in
                        NavigationLink(value: conversation) {
                            ConversationRow(conversation: conversation)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
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

    private func deleteConversation(_ conversation: AIConversation) {
        do {
            try aiService.deleteConversation(id: conversation.id, context: context)
        } catch {
            errorMessage = "Failed to delete conversation: \(error.localizedDescription)"
        }
    }
}

struct ConversationRow: View {
    let conversation: AIConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conversation.title.isEmpty ? "New Chat" : conversation.title)
                .font(.headline)
                .lineLimit(1)

            if let lastMessage = conversation.sortedMessages.last {
                Text(lastMessage.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Text(conversation.updatedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationHistoryView()
}
