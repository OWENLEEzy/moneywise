//
//  ChatAIService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: AI chat conversation service with context persistence
//

import Foundation
import SwiftData

/// # ChatAIService
///
/// ## Overview
/// Service responsible for AI-powered chat conversations with financial context.
/// Manages conversation persistence, message history, and multi-turn dialogue
/// with the Gemini AI assistant.
///
/// ## Usage
/// ```swift
/// let service = ChatAIService(
///     gemini: GeminiService(),
///     apiKeyProvider: { "your-api-key" }
/// )
///
/// // Start new conversation
/// let (response, conversationId) = try await service.chat(
///     message: "How much did I spend on food this week?",
///     conversationId: nil,
///     context: modelContext
/// )
///
/// // Continue conversation
/// let (followUp, _) = try await service.chat(
///     message: "What about last month?",
///     conversationId: conversationId,
///     context: modelContext
/// )
/// ```
///
/// ## Error Handling
/// - `AIServiceError.missingAPIKey`: No API key configured
/// - `AIServiceError.networkError`: Network connectivity issues
/// - `AIServiceError.decodingFailed`: AI response parsing failed
///
/// ## Thread Safety
/// All methods are marked `@MainActor` and must be called from the main thread.
///
/// ## Dependencies
/// - `GeminiService`: Low-level HTTP client for Gemini API
/// - `ModelContext`: SwiftData context for conversation/message persistence
/// - `AIConversation`, `AIMessage`: SwiftData models for chat storage

/// Service responsible for AI chat conversations and message management
final class ChatAIService {
    private let gemini: GeminiService
    private let apiKeyProvider: () -> String?

    /// Initializes the service with required dependencies
    ///
    /// - Parameters:
    ///   - gemini: Low-level Gemini API client
    ///   - apiKeyProvider: Closure that provides the current API key (may return nil)
    init(gemini: GeminiService, apiKeyProvider: @escaping () -> String?) {
        self.gemini = gemini
        self.apiKeyProvider = apiKeyProvider
    }

    /// Send a chat message and get AI response
    ///
    /// This method manages the complete chat workflow:
    /// 1. Finds existing conversation or creates new one
    /// 2. Builds conversation history prompt (last 10 messages)
    /// 3. Sends message to Gemini with context
    /// 4. Saves both user message and AI response
    /// 5. Auto-generates title for new conversations
    ///
    /// - Parameters:
    ///   - message: User's message text
    ///   - conversationId: Optional UUID string of existing conversation (nil for new chat)
    ///   - context: SwiftData context for conversation/message persistence
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Tuple containing AI response text and the (possibly new) conversation ID
    /// - Throws: `AIServiceError` for API failures
    /// - Note: All messages are automatically persisted to SwiftData
    @MainActor
    func chat(message: String, conversationId: String?, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> (response: String, newConversationId: String) {
        let apiKey = apiKeyProvider()
        guard let apiKey else { throw AIServiceError.missingAPIKey }

        // Find or create conversation
        var conversation: AIConversation
        if let idString = conversationId,
           let id = parseUUIDString(idString),
           let existing = try? context.fetch(FetchDescriptor<AIConversation>(predicate: #Predicate { $0.id == id })).first {
            conversation = existing
        } else {
            // Create new conversation
            conversation = AIConversation(title: "New Chat")
            context.insert(conversation)
        }

        // Build conversation history for prompt
        let historyPrompt = buildConversationPrompt(for: conversation, newMessage: message)

        // Send to AI
        let prompt = GeminiPromptBuilder().chatPrompt(message: historyPrompt)
        let data = try await gemini.send(payload: prompt, apiKey: apiKey, cancellationToken: &cancellationToken)
        let geminiResponse = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)

        let responseText = geminiResponse.text

        // Save user message
        let userMessage = AIMessage(role: .user, content: message, timestamp: .now)
        userMessage.conversation = conversation
        context.insert(userMessage)

        // Save AI response
        let assistantMessage = AIMessage(role: .assistant, content: responseText, timestamp: .now)
        assistantMessage.conversation = conversation
        context.insert(assistantMessage)

        // Update conversation timestamp
        conversation.updatedAt = .now

        // Generate title for new conversations (first exchange)
        if conversation.title == "New Chat" || conversation.title.isEmpty {
            conversation.title = try await generateConversationTitle(from: message, context: context)
        }

        context.saveSafe()

        return (responseText, conversation.id.uuidString)
    }

    // MARK: - Conversation Management

    /// Retrieves all non-archived conversations sorted by recent activity
    ///
    /// - Parameter context: SwiftData context for fetching
    /// - Returns: Array of conversations, newest first
    /// - Throws: SwiftData fetch errors
    @MainActor
    func getAllConversations(context: ModelContext) throws -> [AIConversation] {
        let descriptor = FetchDescriptor<AIConversation>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return try context.fetch(descriptor).filter { !$0.isArchived }
    }

    /// Retrieves a specific conversation by ID
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation
    ///   - context: SwiftData context for fetching
    /// - Returns: The conversation if found, nil otherwise
    /// - Throws: SwiftData fetch errors
    @MainActor
    func getConversation(id: UUID, context: ModelContext) throws -> AIConversation? {
        let descriptor = FetchDescriptor<AIConversation>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    /// Permanently deletes a conversation and all its messages
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation to delete
    ///   - context: SwiftData context for deletion
    /// - Throws: SwiftData delete errors
    /// - Note: This is a permanent deletion; use `archiveConversation` for soft delete
    @MainActor
    func deleteConversation(id: UUID, context: ModelContext) throws {
        guard let conversation = try getConversation(id: id, context: context) else { return }
        context.delete(conversation)
        context.saveSafe()
    }

    /// Archives a conversation (soft delete)
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation to archive
    ///   - context: SwiftData context for update
    /// - Throws: SwiftData fetch/update errors
    /// - Note: Archived conversations are hidden from `getAllConversations()`
    @MainActor
    func archiveConversation(id: UUID, context: ModelContext) throws {
        guard let conversation = try getConversation(id: id, context: context) else { return }
        conversation.isArchived = true
        context.saveSafe()
    }

    // MARK: - Private Helpers

    /// Parses a UUID string into a UUID
    ///
    /// - Parameter idString: String representation of UUID
    /// - Returns: UUID if valid, nil otherwise
    private func parseUUIDString(_ idString: String) -> UUID? {
        return UUID(uuidString: idString)
    }

    /// Generates a title for a new conversation based on the first message
    ///
    /// - Parameters:
    ///   - firstMessage: The user's first message in the conversation
    ///   - context: SwiftData context (for potential future AI-based titles)
    /// - Returns: Generated title (truncated to 30 chars)
    /// - Note: Currently uses simple truncation; could use AI for better titles
    @MainActor
    private func generateConversationTitle(from firstMessage: String, context: ModelContext) async throws -> String {
        // Simple title generation based on first message
        // Could use AI to generate better titles
        let maxLength = 30
        if firstMessage.count <= maxLength {
            return firstMessage
        }
        return String(firstMessage.prefix(maxLength)) + "..."
    }

    /// Builds a conversation history prompt for AI context
    ///
    /// Includes up to the last 10 messages to provide context while avoiding
    /// token overflow. Formats messages in a user/assistant dialogue pattern.
    ///
    /// - Parameters:
    ///   - conversation: The conversation to build history from
    ///   - newMessage: The new user message to append
    /// - Returns: Formatted prompt string with conversation history
    /// - Note: Limited to last 10 messages to prevent token overflow
    private func buildConversationPrompt(for conversation: AIConversation, newMessage: String) -> String {
        var prompt = ""

        // Add conversation history (last 10 messages to avoid token overflow)
        let recentMessages = conversation.sortedMessages.suffix(10)
        for msg in recentMessages {
            switch msg.role {
            case .user:
                prompt += "User: \(msg.content)\n"
            case .assistant:
                prompt += "Assistant: \(msg.content)\n"
            case .system:
                prompt += "System: \(msg.content)\n"
            }
        }

        // Add new message
        prompt += "User: \(newMessage)\n"
        prompt += "Please respond to the user's message above, considering the conversation context. You are a helpful financial assistant for the Moneywise app."

        return prompt
    }
}
