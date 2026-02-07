//
//  AnalyticsAIService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: AI-powered spending analysis and insights service
//

import Foundation
import SwiftData

/// # AnalyticsAIService
///
/// ## Overview
/// Service responsible for AI-generated financial insights and spending analysis.
/// Provides two main capabilities: answering analytical questions about transactions
/// and generating structured insight summaries for time periods.
///
/// ## Usage
/// ```swift
/// let service = AnalyticsAIService(
///     gemini: GeminiService(),
///     apiKeyProvider: { "your-api-key" }
/// )
///
/// // Ask a question
/// let answer = try await service.analyze(
///     question: "What's my average weekly food spending?",
///     context: modelContext
/// )
///
/// // Generate insights
/// let insights = try await service.generateInsights(
///     transactions: myTransactions,
///     period: "January 2025",
///     context: modelContext
/// )
/// print(insights.summary)
/// print(insights.insights) // ["You spent 20% more on dining", ...]
/// ```
///
/// ## Error Handling
/// - `AIServiceError.missingAPIKey`: No API key configured
/// - `AIServiceError.decodingFailed`: AI response JSON parsing failed
/// - `AIServiceError.networkError`: Network connectivity issues
///
/// ## Thread Safety
/// All methods are marked `@MainActor` and must be called from the main thread.
///
/// ## Dependencies
/// - `GeminiService`: Low-level HTTP client for Gemini API
/// - `ModelContext`: SwiftData context for fetching transactions
/// - `Prompt.swift`: Analytics and insight prompt templates

/// Service responsible for spending analysis and AI-generated insights
final class AnalyticsAIService {
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

    /// Analyze spending data with a specific question
    ///
    /// Fetches transactions from the last 12 months and sends them to Gemini
    /// along with an analytical question. Returns a free-form text response.
    ///
    /// - Parameters:
    ///   - question: Analytical question to answer (e.g., "What's my average food spending?")
    ///   - context: SwiftData context for fetching transactions
    /// - Returns: AI-generated text answer to the question
    /// - Throws: `AIServiceError` for API failures
    /// - Note: Fetches only transactions from the last 12 months for performance
    @MainActor
    func analyze(question: String, context: ModelContext) async throws -> String {
        // Fetch only transactions from the last 12 months for performance
        let twelveMonthsAgo = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        let predicate = #Predicate<Transaction> { $0.date >= twelveMonthsAgo }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)
        let transactions = try context.fetch(descriptor)

        let dataset = transactions.map { "\($0.date): \($0.note) - \($0.amount)" }.joined(separator: "\n")
        let response = try await gemini.analyze(question: question, dataset: dataset, apiKey: apiKeyProvider())
        return response.text
    }

    /// Generate AI insights for a set of transactions over a period
    ///
    /// Creates a structured insight summary including:
    /// - A high-level summary of spending patterns
    /// - A list of specific insights (anomalies, trends, recommendations)
    ///
    /// Handles markdown code fence stripping in AI responses and proper JSON decoding.
    ///
    /// - Parameters:
    ///   - transactions: Transactions to analyze (already filtered by period)
    ///   - period: Human-readable period description (e.g., "January 2025", "this week")
    ///   - context: SwiftData context for potential future use
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: `GeminiInsightResponse` with summary and insight array
    /// - Throws: `AIServiceError.decodingFailed` if response cannot be parsed as JSON
    /// - Important: The transactions array should be pre-filtered to the desired period
    @MainActor
    func generateInsights(transactions: [Transaction], period: String, context: ModelContext, cancellationToken: inout CancellationToken? = nil) async throws -> GeminiInsightResponse {
        let apiKey = apiKeyProvider()
        guard let apiKey else { throw AIServiceError.missingAPIKey }

        let dataset = transactions.map {
            "\($0.date.formatted(date: .numeric, time: .omitted)): \($0.category?.name ?? "Uncategorized") - \($0.amount) (\($0.note))"
        }.joined(separator: "\n")

        let prompt = GeminiPromptBuilder().insightPrompt(period: period, dataset: dataset)
        let data = try await gemini.send(payload: prompt, apiKey: apiKey, cancellationToken: &cancellationToken)

        do {
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            let rawText = response.text

            // Check if response is empty
            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.decodingFailed
            }

            // Improved JSON extraction - strip markdown code fences first
            var jsonString = rawText

            // Remove markdown code fences like ```json ... ``` or ``` ... ```
            if let jsonBlockRange = rawText.range(of: "```(?:json)?\\s*([\\s\\S]*?)```", options: .regularExpression) {
                let match = String(rawText[jsonBlockRange])
                // Remove the ``` markers
                jsonString = match
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let range = rawText.range(of: "(?s)\\{.*\\}", options: .regularExpression) {
                jsonString = String(rawText[range])
            } else {
                throw AIServiceError.decodingFailed
            }

            // Clean up whitespace
            jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let textData = jsonString.data(using: .utf8) else {
                throw AIServiceError.decodingFailed
            }

            do {
                let decoded = try JSONDecoder.gemini.decode(GeminiInsightResponse.self, from: textData)
                return decoded
            } catch {
                throw AIServiceError.decodingFailed
            }
        } catch {
            throw AIServiceError.decodingFailed
        }
    }
}
