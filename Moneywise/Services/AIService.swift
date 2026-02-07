//
//  AIService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Facade service providing unified interface to all AI operations
//

import Foundation
import SwiftData
import Combine

/// # AIService
///
/// ## Overview
/// Facade service that provides a unified interface to all AI operations in the app.
/// Delegates to specialized services for transaction parsing, chat, and analytics.
/// This is the primary entry point for all AI functionality.
///
/// ## Usage
/// ```swift
/// let aiService = AIService(apiKeyProvider: { "your-api-key" })
///
/// // Parse transaction
/// let transaction = try await aiService.parse(
///     text: "spent $30 on lunch",
///     context: modelContext
/// )
///
/// // Chat with AI
/// let (response, conversationId) = try await aiService.chat(
///     message: "How much did I spend this week?",
///     conversationId: nil,
///     context: modelContext
/// )
///
/// // Generate insights
/// let insights = try await aiService.generateInsights(
///     transactions: transactions,
///     period: "January 2025",
///     context: modelContext
/// )
/// ```
///
/// ## Error Handling
/// All errors from underlying services are propagated:
/// - `AIServiceError.missingAPIKey`: No API key configured
/// - `AIServiceError.invalidAPIKey`: Invalid API key
/// - `AIServiceError.networkError`: Network connectivity issues
/// - `AIServiceError.decodingFailed`: Response parsing failed
///
/// ## Thread Safety
/// All public methods are marked `@MainActor` and must be called from the main thread.
///
/// ## Dependencies
/// - `TransactionParsingService`: Natural language to transaction conversion
/// - `ChatAIService`: Conversational AI with history
/// - `AnalyticsAIService`: Spending analysis and insights
/// - All underlying services use `GeminiService` for API communication

/// Facade service that delegates AI operations to specialized services
final class AIService {
    private let transactionParsing: TransactionParsingService
    private let chat: ChatAIService
    private let analytics: AnalyticsAIService

    /// Initializes the AI service with all specialized subservices
    ///
    /// - Parameter apiKeyProvider: Closure that provides the current Gemini API key (may return nil)
    /// - Note: All subservices share a single `GeminiService` instance for efficiency
    init(apiKeyProvider: @escaping () -> String?) {
        let gemini = GeminiService()
        self.transactionParsing = TransactionParsingService(gemini: gemini, apiKeyProvider: apiKeyProvider)
        self.chat = ChatAIService(gemini: gemini, apiKeyProvider: apiKeyProvider)
        self.analytics = AnalyticsAIService(gemini: gemini, apiKeyProvider: apiKeyProvider)
    }

    // MARK: - Transaction Parsing

    /// Parses natural language text into a Transaction object
    ///
    /// Delegates to `TransactionParsingService.parse()`.
    ///
    /// - Parameters:
    ///   - text: Natural language input (e.g., "spent $30 on lunch")
    ///   - context: SwiftData context for category lookup
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Fully populated `Transaction` object
    /// - Throws: `AIServiceError` for parsing failures
    @MainActor
    func parse(text: String, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> Transaction {
        return try await transactionParsing.parse(text: text, context: context, cancellationToken: &cancellationToken)
    }

    /// Saves a pre-parsed response as a Transaction
    ///
    /// Delegates to `TransactionParsingService.saveTransaction()`.
    ///
    /// - Parameters:
    ///   - response: Previously parsed AI response
    ///   - context: SwiftData context for insertion
    /// - Throws: Category lookup errors
    @MainActor
    func saveTransaction(_ response: GeminiResponse, in context: ModelContext) async throws {
        try await transactionParsing.saveTransaction(response, in: context)
    }

    // MARK: - Chat & Conversations

    /// Sends a chat message and returns AI response
    ///
    /// Delegates to `ChatAIService.chat()`.
    ///
    /// - Parameters:
    ///   - message: User's message text
    ///   - conversationId: Optional existing conversation ID (nil for new chat)
    ///   - context: SwiftData context for conversation persistence
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Tuple of response text and conversation ID
    /// - Throws: `AIServiceError` for API failures
    @MainActor
    func chat(message: String, conversationId: String?, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> (response: String, newConversationId: String) {
        return try await chat.chat(message: message, conversationId: conversationId, context: context, cancellationToken: &cancellationToken)
    }

    /// Retrieves all non-archived conversations
    ///
    /// Delegates to `ChatAIService.getAllConversations()`.
    ///
    /// - Parameter context: SwiftData context for fetching
    /// - Returns: Array of conversations, newest first
    /// - Throws: SwiftData fetch errors
    @MainActor
    func getAllConversations(context: ModelContext) throws -> [AIConversation] {
        return try chat.getAllConversations(context: context)
    }

    /// Retrieves a specific conversation by ID
    ///
    /// Delegates to `ChatAIService.getConversation()`.
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation
    ///   - context: SwiftData context for fetching
    /// - Returns: The conversation if found, nil otherwise
    /// - Throws: SwiftData fetch errors
    @MainActor
    func getConversation(id: UUID, context: ModelContext) throws -> AIConversation? {
        return try chat.getConversation(id: id, context: context)
    }

    /// Permanently deletes a conversation
    ///
    /// Delegates to `ChatAIService.deleteConversation()`.
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation to delete
    ///   - context: SwiftData context for deletion
    /// - Throws: SwiftData delete errors
    @MainActor
    func deleteConversation(id: UUID, context: ModelContext) throws {
        try chat.deleteConversation(id: id, context: context)
    }

    /// Archives a conversation (soft delete)
    ///
    /// Delegates to `ChatAIService.archiveConversation()`.
    ///
    /// - Parameters:
    ///   - id: UUID of the conversation to archive
    ///   - context: SwiftData context for update
    /// - Throws: SwiftData update errors
    @MainActor
    func archiveConversation(id: UUID, context: ModelContext) throws {
        try chat.archiveConversation(id: id, context: context)
    }

    // MARK: - Analytics & Insights

    /// Asks an analytical question about spending data
    ///
    /// Delegates to `AnalyticsAIService.analyze()`.
    ///
    /// - Parameters:
    ///   - question: Analytical question to answer
    ///   - context: SwiftData context for fetching transactions
    /// - Returns: AI-generated text answer
    /// - Throws: `AIServiceError` for API failures
    @MainActor
    func analyze(question: String, context: ModelContext) async throws -> String {
        return try await analytics.analyze(question: question, context: context)
    }

    /// Generates AI insights for a time period
    ///
    /// Delegates to `AnalyticsAIService.generateInsights()`.
    ///
    /// - Parameters:
    ///   - transactions: Pre-filtered transactions for the period
    ///   - period: Human-readable period description
    ///   - context: SwiftData context
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Structured insights with summary and bullet points
    /// - Throws: `AIServiceError` for parsing failures
    @MainActor
    func generateInsights(transactions: [Transaction], period: String, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> GeminiInsightResponse {
        return try await analytics.generateInsights(transactions: transactions, period: period, context: context, cancellationToken: &cancellationToken)
    }
}
