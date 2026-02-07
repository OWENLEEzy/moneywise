//
//  GeminiService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Low-level HTTP client for communicating with Google Gemini 2.5 Flash API
//

import Foundation

/// # GeminiService
///
/// ## Overview
/// Low-level service responsible for direct HTTP communication with Google's Gemini 2.5 Flash API.
/// Handles request formatting, response parsing, error handling, retry logic, and proxy configuration.
///
/// ## Usage
/// ```swift
/// let service = GeminiService()
/// let response = try await service.parseTransaction(
///     prompt: "spent $30 on lunch",
///     apiKey: "your-api-key"
/// )
/// ```
///
/// ## Error Handling
/// - `AIServiceError.missingAPIKey`: No API key provided
/// - `AIServiceError.invalidAPIKey`: API key rejected by Google
/// - `AIServiceError.networkError`: Network connectivity issues
/// - `AIServiceError.serverError`: 5xx errors with automatic retry
/// - `AIServiceError.clientError`: 4xx errors (429 rate limit has special retry handling)
/// - `AIServiceError.decodingFailed`: JSON response parsing failed
///
/// ## Thread Safety
/// This class is thread-safe. All methods are async and can be called from any context.
///
/// ## Dependencies
/// - Foundation: URLSession for HTTP requests
/// - UserDefaults: For custom base URL and proxy configuration
/// - Prompt.swift: Uses `GeminiPromptBuilder` for request formatting
///
/// ## Configuration
/// - Custom base URL can be set via UserDefaults key "customBaseURL"
/// - Proxy settings can be enabled via UserDefaults keys:
///   - "proxyEnabled": Bool
///   - "proxyHost": String (default: "127.0.0.1")
///   - "proxyPort": Int (default: 50960)

/// Low-level service for communicating with Google Gemini API
final class GeminiService {
    private let session: URLSession

    private func getBaseURL() throws -> URL {
        let customURL = UserDefaults.standard.string(forKey: "customBaseURL") ?? ""
        let host = customURL.isEmpty ? "https://generativelanguage.googleapis.com" : customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        guard let url = URL(string: "\(cleanHost)/v1beta/models/gemini-2.5-flash:generateContent") else {
            throw AIServiceError.invalidConfiguration("Invalid URL configuration: \(cleanHost)")
        }
        return url
    }

    /// Initializes the service with optional proxy configuration
    ///
    /// Proxy settings are read from UserDefaults:
    /// - "proxyEnabled": Boolean flag to enable proxy
    /// - "proxyHost": Proxy hostname (default: "127.0.0.1")
    /// - "proxyPort": Proxy port (default: 50960)
    init() {
        let config = URLSessionConfiguration.default

        // Read proxy settings from UserDefaults (can be configured in Settings)
        let proxyEnabled = UserDefaults.standard.bool(forKey: "proxyEnabled")
        if proxyEnabled {
            let proxyHost = UserDefaults.standard.string(forKey: "proxyHost") ?? "127.0.0.1"
            let proxyPort = UserDefaults.standard.integer(forKey: "proxyPort")
            let port = proxyPort > 0 ? proxyPort : 50960

            config.connectionProxyDictionary = [
                "HTTPEnable": 1,
                "HTTPProxy": proxyHost,
                "HTTPPort": port,
                "HTTPSEnable": 1,
                "HTTPSProxy": proxyHost,
                "HTTPSPort": port
            ]
        }

        self.session = URLSession(configuration: config)
    }

    /// Parses natural language input into structured transaction data
    ///
    /// Sends a transaction parsing prompt to Gemini and decodes the JSON response.
    /// Handles markdown code fences in responses and performs retries on server errors.
    ///
    /// - Parameters:
    ///   - prompt: Natural language text describing a transaction (e.g., "spent $30 on lunch")
    ///   - apiKey: Gemini API key (optional, will throw if nil)
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Structured transaction data with amount, type, category, and confidence score
    /// - Throws: `AIServiceError` for API, network, or decoding failures
    func parseTransaction(prompt: String, apiKey: String?, cancellationToken: inout CancellationToken? = nil) async throws -> GeminiResponse {
        guard let apiKey else {
            throw AIServiceError.missingAPIKey
        }

        let payload = GeminiPromptBuilder().transactionPrompt(with: prompt)
        let data = try await send(payload: payload, apiKey: apiKey, cancellationToken: &cancellationToken)

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
                let decoded = try JSONDecoder.gemini.decode(GeminiResponse.self, from: textData)
                return decoded
            } catch {
                throw AIServiceError.decodingFailed
            }
        } catch let error as AIServiceError {
            throw error
        } catch {
            throw AIServiceError.decodingFailed
        }
    }

    /// Analyzes transaction data with a specific question
    ///
    /// Sends transaction data and a question to Gemini for text-based analysis.
    /// Returns raw text response (not JSON).
    ///
    /// - Parameters:
    ///   - question: Analytical question to ask about the data
    ///   - dataset: Formatted transaction data string
    ///   - apiKey: Gemini API key (optional, will throw if nil)
    ///   - cancellationToken: Optional token to cancel the request
    /// - Returns: Text response from Gemini
    /// - Throws: `AIServiceError` for API or network failures
    func analyze(question: String, dataset: String, apiKey: String?, cancellationToken: inout CancellationToken? = nil) async throws -> GeminiTextResponse {
        guard let apiKey else { throw AIServiceError.missingAPIKey }
        let prompt = GeminiPromptBuilder().analysisPrompt(question: question, dataset: dataset)
        let data = try await send(payload: prompt, apiKey: apiKey, cancellationToken: &cancellationToken)
        do {
            return try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }

    /// Sends a payload to Gemini API with retry logic
    ///
    /// Implements exponential backoff retry for server errors (5xx) and rate limit errors (429).
    /// Cancellation is checked before each retry attempt.
    ///
    /// ## Retry Strategy
    /// - Server errors (5xx): 1s, 2s, 4s delays (3 attempts)
    /// - Rate limit (429): 2s, 4s, 8s delays (3 attempts)
    /// - Other errors: No retry
    ///
    /// - Parameters:
    ///   - payload: Structured Gemini API request payload
    ///   - apiKey: Gemini API key
    ///   - cancellationToken: Optional token to cancel the request and retries
    /// - Returns: Raw response data
    /// - Throws: `AIServiceError` for all failures after retries exhausted
    func send(payload: GeminiPromptBuilder.Payload, apiKey: String, cancellationToken: inout CancellationToken? = nil) async throws -> Data {
        let maxRetries = 3
        var lastError: Error = AIServiceError.invalidResponse

        for attempt in 1...maxRetries {
            // Check for cancellation before each retry attempt
            try cancellationToken?.checkCancellation()

            do {
                return try await performRequest(payload: payload, apiKey: apiKey)
            } catch AIServiceError.serverError(let code) {
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000 // 1s, 2s, 4s
                    try? await Task.sleep(nanoseconds: delay)
                    // Check for cancellation after delay
                    try cancellationToken?.checkCancellation()
                }
            } catch AIServiceError.clientError(429, _) {
                lastError = AIServiceError.clientError(429, "Rate limit exceeded. Please try again later.")

                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000 // 2s, 4s, 8s for rate limits
                    try? await Task.sleep(nanoseconds: delay)
                    // Check for cancellation after delay
                    try cancellationToken?.checkCancellation()
                }
            } catch {
                // Non-retryable error
                throw error
            }
        }

        throw lastError
    }

    /// Performs a single HTTP request to the Gemini API
    ///
    /// Handles URL construction, request headers, response parsing, and error mapping.
    ///
    /// - Parameters:
    ///   - payload: Structured Gemini API request payload
    ///   - apiKey: Gemini API key (sent as x-goog-api-key header)
    /// - Returns: Raw response data
    /// - Throws: `AIServiceError` with appropriate error type based on HTTP status
    /// - Note: This method does NOT implement retry logic; use `send()` for retries
    private func performRequest(payload: GeminiPromptBuilder.Payload, apiKey: String) async throws -> Data {
        let baseURL = try getBaseURL()
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIServiceError.invalidResponse
            }

            if (200..<300).contains(httpResponse.statusCode) {
                return data
            }

            // Parse error details from Google
            var errorMessage = "Unknown Error"
            if let errorJson = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data) {
                errorMessage = errorJson.error.message
            } else if let errorText = String(data: data, encoding: .utf8) {
                errorMessage = errorText
            }

            switch httpResponse.statusCode {
            case 400:
                if errorMessage.contains("API_KEY_INVALID") {
                    throw AIServiceError.invalidAPIKey
                }
                throw AIServiceError.clientError(400, errorMessage)
            case 401, 403:
                throw AIServiceError.invalidAPIKey
            case 404:
                throw AIServiceError.clientError(404, "Model not found or invalid endpoint. \(errorMessage)")
            case 429:
                throw AIServiceError.clientError(429, "Rate limit exceeded. Please try again later.")
            case 500..<600:
                throw AIServiceError.serverError(httpResponse.statusCode)
            default:
                throw AIServiceError.clientError(httpResponse.statusCode, errorMessage)
            }
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw AIServiceError.networkError("No Internet Connection")
            case .timedOut:
                throw AIServiceError.networkError("Request Timed Out")
            case .cannotFindHost, .cannotConnectToHost:
                throw AIServiceError.networkError("Host Unreachable")
            default:
                throw AIServiceError.networkError(error.localizedDescription)
            }
        } catch {
            throw error
        }
    }
}

// MARK: - Supporting Types

/// Helper for parsing Google error responses
struct GoogleErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let code: Int
        let message: String
        let status: String
    }
    let error: ErrorDetail
}

/// Flattened transaction response from Gemini parsing
///
/// Contains all fields that AI may extract from natural language input.
/// All fields are optional to handle partial parsing.
struct GeminiResponse: Decodable {
    let amount: Double?
    let type: TransactionType?
    let category: String?
    let account: String?
    let paymentMethod: String?
    let note: String?
    let confidence: Double?
    let date: Date?
}

/// Raw text response from Gemini API
///
/// Wraps the standard Gemini API response format with candidates and usage metadata.
struct GeminiTextResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
            }

            let parts: [Part]
        }

        let content: Content
    }

    struct UsageMetadata: Decodable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
    }

    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?

    /// Convenience property to extract text from first candidate
    var text: String {
        candidates.first?.content.parts.compactMap { $0.text }.joined(separator: "\n") ?? ""
    }
}

/// Structured insight response for analytics
///
/// Contains AI-generated summary and list of insights for transaction analysis.
struct GeminiInsightResponse: Decodable {
    let summary: String
    let insights: [String]
}

/// Errors that can occur during AI service operations
enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed
    case networkError(String)
    case invalidAPIKey
    case serverError(Int)
    case clientError(Int, String)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Please configure Gemini API Key first"
        case .invalidResponse: return "AI response error, please try again later"
        case .decodingFailed: return "Failed to parse AI response"
        case .networkError(let message): return "Network Error: \(message)"
        case .invalidAPIKey: return "Invalid API Key. Please check your key."
        case .serverError(let code): return "Server Error (Code: \(code)). Please try again later."
        case .clientError(let code, let message): return "Request Error (Code: \(code)): \(message)"
        case .invalidConfiguration(let message): return "Configuration Error: \(message)"
        }
    }
}

/// JSONDecoder configured for Gemini API responses
///
/// - Uses snake_case key decoding strategy
/// - Handles multiple date formats: ISO8601 with/without fractional seconds, and date-only (YYYY-MM-DD)
extension JSONDecoder {
    static let gemini: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Custom date decoding to handle both "YYYY-MM-DD" and full ISO8601
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try full ISO8601 first
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }

            // Try date-only format "YYYY-MM-DD"
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateOnlyFormatter.timeZone = TimeZone.current
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from '\(dateString)'")
        }

        return decoder
    }()
}

/// Builder for Gemini API request payloads
///
/// Creates properly formatted requests for different AI operations:
/// - Transaction parsing (JSON response)
/// - Data analysis (text response)
/// - Insight generation (JSON response)
/// - Chat (text response)
struct GeminiPromptBuilder {
    struct Payload: Encodable {
        struct Content: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let parts: [Part]
        }

        let contents: [Content]
        let generationConfig: GenerationConfig
    }

    struct GenerationConfig: Encodable {
        let responseMimeType: String
    }

    /// Creates a payload for transaction parsing
    ///
    /// - Parameter text: Natural language transaction description
    /// - Returns: Payload configured for JSON response
    func transactionPrompt(with text: String) -> Payload {
        let jsonTemplate = Prompt.transaction(text: text)
        return Payload(
            contents: [.init(parts: [.init(text: jsonTemplate)])],
            generationConfig: .init(responseMimeType: "application/json")
        )
    }

    /// Creates a payload for data analysis
    ///
    /// - Parameters:
    ///   - question: Analytical question to answer
    ///   - dataset: Transaction data to analyze
    /// - Returns: Payload configured for text response
    func analysisPrompt(question: String, dataset: String) -> Payload {
        let instruction = Prompt.analysis(question: question, dataset: dataset)
        return Payload(
            contents: [.init(parts: [.init(text: instruction)])],
            generationConfig: .init(responseMimeType: "text/plain")
        )
    }

    /// Creates a payload for insight generation
    ///
    /// - Parameters:
    ///   - period: Time period for insights (e.g., "this month", "last week")
    ///   - dataset: Transaction data to analyze
    /// - Returns: Payload configured for JSON response
    func insightPrompt(period: String, dataset: String) -> Payload {
        let jsonTemplate = Prompt.insight(period: period, dataset: dataset)

        return Payload(
            contents: [.init(parts: [.init(text: jsonTemplate)])],
            generationConfig: .init(responseMimeType: "application/json")
        )
    }

    /// Creates a payload for chat interactions
    ///
    /// - Parameter message: User message to send
    /// - Returns: Payload configured for text response
    func chatPrompt(message: String) -> Payload {
        return Payload(
            contents: [.init(parts: [.init(text: message)])],
            generationConfig: .init(responseMimeType: "text/plain")
        )
    }
}
