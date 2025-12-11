import Foundation
import SwiftData
import Combine

final class AIService {
    private let gemini: GeminiService
    private let apiKeyProvider: () -> String?

    init(apiKeyProvider: @escaping () -> String?) {
        self.gemini = GeminiService()
        self.apiKeyProvider = apiKeyProvider
    }

    @MainActor
    func parse(text: String, context: ModelContext) async throws -> Transaction {
        let parsed = try await gemini.parseTransaction(prompt: text, apiKey: apiKeyProvider())
        
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

    @MainActor
    func analyze(question: String, context: ModelContext) async throws -> String {
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let dataset = transactions.map { "\($0.date): \($0.note) - \($0.amount)" }.joined(separator: "\n")
        let response = try await gemini.analyze(question: question, dataset: dataset, apiKey: apiKeyProvider())
        return response.text
    }

    @MainActor
    func generateInsights(transactions: [Transaction], period: String, context: ModelContext) async throws -> GeminiInsightResponse {
        let apiKey = apiKeyProvider()
        guard let apiKey else { throw AIServiceError.missingAPIKey }
        
        let dataset = transactions.map { 
            "\($0.date.formatted(date: .numeric, time: .omitted)): \($0.category?.name ?? "Uncategorized") - \($0.amount) (\($0.note))" 
        }.joined(separator: "\n")
        
        let prompt = GeminiPromptBuilder().insightPrompt(period: period, dataset: dataset)
        let data = try await gemini.send(payload: prompt, apiKey: apiKey)
        
        do {
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            let rawText = response.text
            return try JSONDecoder.gemini.decode(GeminiInsightResponse.self, from: textData)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }

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
        try context.save()
    }

    @MainActor
    func chat(message: String, conversationId: String?) async throws -> (response: String, newConversationId: String) {
        let apiKey = apiKeyProvider()
        guard let apiKey else { throw AIServiceError.missingAPIKey }
        
        // In a real implementation, we would maintain conversation history using conversationId.
        // For now, we'll just send the message as a single turn, but return a dummy ID.
        let prompt = GeminiPromptBuilder().chatPrompt(message: message)
        let data = try await gemini.send(payload: prompt, apiKey: apiKey)
        
        let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
        return (response.text, conversationId ?? UUID().uuidString)
    }
}

final class GeminiService {
    private let session: URLSession
    
    private var baseURL: URL {
        let customURL = UserDefaults.standard.string(forKey: "customBaseURL") ?? ""
        let host = customURL.isEmpty ? "https://generativelanguage.googleapis.com" : customURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        return URL(string: "\(cleanHost)/v1beta/models/gemini-2.5-flash:generateContent")!
    }

    init() {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [
            "HTTPEnable": 1,
            "HTTPProxy": "127.0.0.1",
            "HTTPPort": 50960,
            "HTTPSEnable": 1,
            "HTTPSProxy": "127.0.0.1",
            "HTTPSPort": 50960
        ]
        self.session = URLSession(configuration: config)
    }

    func parseTransaction(prompt: String, apiKey: String?) async throws -> GeminiResponse {
        guard let apiKey else { 
            throw AIServiceError.missingAPIKey 
        }
        
        let payload = GeminiPromptBuilder().transactionPrompt(with: prompt)
        let data = try await send(payload: payload, apiKey: apiKey)
        
        do {
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            let rawText = response.text
            
            // Check if response is empty
            guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.decodingFailed
            }
            
            // Improved JSON extraction – strip markdown code fences first
            var jsonString = rawText
            
            // Remove markdown code fences like ```json ... ``` or ``` ... ```
            if let jsonBlockRange = rawText.range(of: "```(?:json)?\\s*([\\s\\S]*?)```", options: .regularExpression) {
                let match = String(rawText[jsonBlockRange])
                // Remove the ``` markers
                jsonString = match
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
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


    func analyze(question: String, dataset: String, apiKey: String?) async throws -> GeminiTextResponse {
        guard let apiKey else { throw AIServiceError.missingAPIKey }
        let prompt = GeminiPromptBuilder().analysisPrompt(question: question, dataset: dataset)
        let data = try await send(payload: prompt, apiKey: apiKey)
        do {
            return try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }

    func send(payload: GeminiPromptBuilder.Payload, apiKey: String) async throws -> Data {
        let maxRetries = 3
        var lastError: Error = AIServiceError.invalidResponse
        
        for attempt in 1...maxRetries {
            do {
                return try await performRequest(payload: payload, apiKey: apiKey)
            } catch AIServiceError.serverError(let code) {
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000 // 1s, 2s, 4s
                    try? await Task.sleep(nanoseconds: delay)
                }
            } catch AIServiceError.clientError(429, _) {
                lastError = AIServiceError.clientError(429, "Rate limit exceeded. Please try again later.")
                
                if attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000 // 2s, 4s, 8s for rate limits
                    try? await Task.sleep(nanoseconds: delay)
                }
            } catch {
                // Non-retryable error
                throw error
            }
        }
        
        throw lastError
    }
    
    private func performRequest(payload: GeminiPromptBuilder.Payload, apiKey: String) async throws -> Data {
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


// Helper for parsing Google errors
struct GoogleErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let code: Int
        let message: String
        let status: String
    }
    let error: ErrorDetail
}

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

    func transactionPrompt(with text: String) -> Payload {
        let jsonTemplate = Prompt.transaction(text: text)
        return Payload(
            contents: [.init(parts: [.init(text: jsonTemplate)])],
            generationConfig: .init(responseMimeType: "application/json")
        )
    }

    func analysisPrompt(question: String, dataset: String) -> Payload {
        let instruction = Prompt.analysis(question: question, dataset: dataset)
        return Payload(
            contents: [.init(parts: [.init(text: instruction)])],
            generationConfig: .init(responseMimeType: "text/plain")
        )
    }
    
    func insightPrompt(period: String, dataset: String) -> Payload {
        let jsonTemplate = Prompt.insight(period: period, dataset: dataset)
        
        return Payload(
            contents: [.init(parts: [.init(text: jsonTemplate)])],
            generationConfig: .init(responseMimeType: "application/json")
        )
    }

    func chatPrompt(message: String) -> Payload {
        return Payload(
            contents: [.init(parts: [.init(text: message)])],
            generationConfig: .init(responseMimeType: "text/plain")
        )
    }
}

// Flattened GeminiResponse to match the JSON output from the AI
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

    var text: String {
        candidates.first?.content.parts.compactMap { $0.text }.joined(separator: "\n") ?? ""
    }
}

struct GeminiInsightResponse: Decodable {
    let summary: String
    let insights: [String]
}

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed
    case networkError(String)
    case invalidAPIKey
    case serverError(Int)
    case clientError(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Please configure Gemini API Key first"
        case .invalidResponse: return "AI response error, please try again later"
        case .decodingFailed: return "Failed to parse AI response"
        case .networkError(let message): return "Network Error: \(message)"
        case .invalidAPIKey: return "Invalid API Key. Please check your key."
        case .serverError(let code): return "Server Error (Code: \(code)). Please try again later."
        case .clientError(let code, let message): return "Request Error (Code: \(code)): \(message)"
        }
    }
}

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
            
            if let date = dateOnlyFormatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date from '\(dateString)'")
        }
        
        return decoder
    }()
}

