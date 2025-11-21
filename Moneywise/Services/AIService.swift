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
        let category = try context.category(named: parsed.category, type: parsed.type)
        
        return Transaction(
            amount: Decimal(parsed.amount),
            type: parsed.type,
            category: category,
            account: parsed.account,
            date: parsed.date,
            note: parsed.note,
            paymentMethod: parsed.paymentMethod,
            isAIGenerated: true,
            confidence: parsed.confidence
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
            guard let text = response.text.data(using: .utf8) else {
                throw AIServiceError.decodingFailed
            }
            return try JSONDecoder.gemini.decode(GeminiInsightResponse.self, from: text)
        } catch {
            throw AIServiceError.decodingFailed
        }
    }
}

final class GeminiService {
    private let session: URLSession
    // Using stable Gemini 1.5 Flash model
    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-001:generateContent")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func parseTransaction(prompt: String, apiKey: String?) async throws -> GeminiResponse {
        print("🔑 [AI Debug] Checking API Key... Has key: \(apiKey != nil), Key length: \(apiKey?.count ?? 0)")
        guard let apiKey else { 
            print("❌ [AI Debug] API Key is missing!")
            throw AIServiceError.missingAPIKey 
        }
        
        let payload = GeminiPromptBuilder().transactionPrompt(with: prompt)
        let data = try await send(payload: payload, apiKey: apiKey)
        do {
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            // Clean up the text response to ensure it's valid JSON
            let cleanText = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            
            guard let textData = cleanText.data(using: .utf8) else {
                throw AIServiceError.decodingFailed
            }
            return try JSONDecoder.gemini.decode(GeminiResponse.self, from: textData)
        } catch {
            print("Decoding error: \(error)")
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
            
            print("❌ [AI Debug] API Error \(httpResponse.statusCode): \(errorMessage)")
            
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
            case 500..<600:
                throw AIServiceError.serverError(httpResponse.statusCode)
            case 429:
                throw AIServiceError.clientError(429, "Rate limit exceeded. Please try again later.")
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
}

// Flattened GeminiResponse to match the JSON output from the AI
struct GeminiResponse: Decodable {
    let amount: Double
    let type: TransactionType
    let category: String
    let account: String
    let paymentMethod: String
    let note: String
    let confidence: Double
    let date: Date
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
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
