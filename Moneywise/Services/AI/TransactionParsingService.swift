//
//  TransactionParsingService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: AI-powered natural language transaction parsing service
//

import Foundation
import SwiftData

/// # TransactionParsingService
///
/// ## Overview
/// Service responsible for converting natural language input into structured `Transaction` objects
/// using Google Gemini AI. Handles the parsing workflow including AI inference, category matching,
/// and entity creation.
///
/// ## Usage
/// ```swift
/// let service = TransactionParsingService(
///     gemini: GeminiService(),
///     apiKeyProvider: { "your-api-key" }
/// )
/// let transaction = try await service.parse(
///     text: "spent $30 on lunch at Cafe",
///     context: modelContext
/// )
/// ```
///
/// ## Error Handling
/// - `AIServiceError.missingAPIKey`: No API key configured
/// - `AIServiceError.decodingFailed`: AI response could not be parsed
/// - `ModelContext.category() errors`: Category lookup/creation failures
///
/// ## Thread Safety
/// All methods are marked `@MainActor` and must be called from the main thread.
///
/// ## Dependencies
/// - `GeminiService`: Low-level HTTP client for Gemini API
/// - `ModelContext`: SwiftData context for category lookup and transaction insertion
/// - `Prompt.swift`: Transaction parsing prompt templates

/// Service responsible for parsing user input into transaction objects using AI
final class TransactionParsingService {
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

    /// Parses natural language text into a Transaction object
    ///
    /// This method orchestrates the AI parsing workflow:
    /// 1. Sends text to Gemini for structured extraction
    /// 2. Maps extracted category name to `SpendingCategory` (creates if needed)
    /// 3. Constructs a `Transaction` with all extracted fields
    /// 4. Includes AI confidence score for verification UI
    ///
    /// - Parameters:
    ///   - text: Natural language input (e.g., "spent $30 on lunch", "income $5000 salary")
    ///   - context: SwiftData context for category lookup
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Fully populated `Transaction` object (not yet persisted)
    /// - Throws: `AIServiceError` for API failures, or category lookup errors
    /// - Note: The returned transaction is NOT automatically inserted into the context
    @MainActor
    func parse(text: String, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> Transaction {
        let parsed = try await gemini.parseTransaction(prompt: text, apiKey: apiKeyProvider(), cancellationToken: &cancellationToken)

        let amount = Decimal(parsed.amount ?? 0.0)
        let type = parsed.type ?? .expense
        let categoryName = parsed.category ?? "Uncategorized"
        let category = try context.category(named: categoryName, type: type)

        return Transaction(
            amount: amount,
            type: type,
            category: category,
            account: parsed.account ?? "Cash",
            date: parsed.date ?? Date(),
            note: parsed.note ?? "",
            paymentMethod: parsed.paymentMethod ?? "Cash",
            isAIGenerated: true,
            confidence: parsed.confidence ?? 0.5
        )
    }

    /// Saves a parsed GeminiResponse as a Transaction in the context
    ///
    /// Alternative workflow that accepts a pre-parsed `GeminiResponse` and directly
    /// persists it to the database. Useful for batch processing or when you have
    /// already parsed the response.
    ///
    /// - Parameters:
    ///   - response: Previously parsed AI response
    ///   - context: SwiftData context for insertion
    /// - Throws: Category lookup errors
    /// - Note: This method DOES persist the transaction to the database
    @MainActor
    func saveTransaction(_ response: GeminiResponse, in context: ModelContext) async throws {
        let amount = Decimal(response.amount ?? 0.0)
        let type = response.type ?? .expense
        let categoryName = response.category ?? "Uncategorized"
        let category = try context.category(named: categoryName, type: type)

        let transaction = Transaction(
            amount: amount,
            type: type,
            category: category,
            account: response.account ?? "Cash",
            date: response.date ?? Date(),
            note: response.note ?? "",
            paymentMethod: response.paymentMethod ?? "Cash",
            isAIGenerated: true,
            confidence: response.confidence ?? 0.5
        )
        context.insert(transaction)
        context.saveSafe()
    }
}
