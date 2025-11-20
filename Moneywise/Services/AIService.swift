import Foundation
import SwiftData
import Combine

@MainActor
final class AIService {
    private let gemini: GeminiService
    private let apiKeyProvider: () -> String?

    init(apiKeyProvider: @escaping () -> String?) {
        self.gemini = GeminiService()
        self.apiKeyProvider = apiKeyProvider
    }

    func parse(text: String, context: ModelContext) async throws -> Transaction {
        let response = try await gemini.parseTransaction(prompt: text, apiKey: apiKeyProvider())
        let parsed = response.transaction
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

    func analyze(question: String, context: ModelContext) async throws -> String {
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let dataset = transactions.map { "\($0.date): \($0.note) - \($0.amount)" }.joined(separator: "\n")
        let response = try await gemini.analyze(question: question, dataset: dataset, apiKey: apiKeyProvider())
        return response.text
    }
}


struct GeminiResponse: Decodable {
    struct ParsedTransaction: Decodable {
        let amount: Double
        let type: TransactionType
        let category: String
        let account: String
        let paymentMethod: String
        let note: String
        let confidence: Double
        let date: Date
    }

    let transaction: ParsedTransaction
    let usage: Usage

    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
    }
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

    var usage: GeminiResponse.Usage {
        GeminiResponse.Usage(
            inputTokens: usageMetadata?.promptTokenCount ?? 0,
            outputTokens: usageMetadata?.candidatesTokenCount ?? 0
        )
    }
}

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先配置 Gemini API Key"
        case .invalidResponse: return "AI 响应异常，请稍后重试"
        case .decodingFailed: return "无法解析 AI 返回内容"
        }
    }
}

final class GeminiService {
    private let session: URLSession
    private let baseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func parseTransaction(prompt: String, apiKey: String?) async throws -> GeminiResponse {
        guard let apiKey else { throw AIServiceError.missingAPIKey }
        let payload = GeminiPromptBuilder().transactionPrompt(with: prompt)
        let data = try await send(payload: payload, apiKey: apiKey)
        do {
            let response = try JSONDecoder.gemini.decode(GeminiTextResponse.self, from: data)
            guard let text = response.text.data(using: .utf8) else {
                throw AIServiceError.decodingFailed
            }
            return try JSONDecoder.gemini.decode(GeminiResponse.self, from: text)
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

    private func send(payload: GeminiPromptBuilder.Payload, apiKey: String) async throws -> Data {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw AIServiceError.invalidResponse
        }
        return data
    }
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
        let jsonTemplate = """
        Analyze the following user input and return a JSON object representing the transaction.
        The JSON object should have the following fields: "amount" (number), "type" (string, "expense" or "income"), "category" (string), "account" (string), "paymentMethod" (string), "note" (string), "confidence" (number, 0-1), and "date" (string, ISO8601 format).
        User input: "\(text)"
        """
        return Payload(
            contents: [.init(parts: [.init(text: jsonTemplate)])],
            generationConfig: .init(responseMimeType: "application/json")
        )
    }

    func analysisPrompt(question: String, dataset: String) -> Payload {
        let instruction = """
        You are a friendly financial assistant. Please provide a specific analysis and suggestions based on the following billing data. Your tone should be empathetic and avoid lecturing.
        Data: \(dataset)
        User question: \(question)
        """
        return Payload(
            contents: [.init(parts: [.init(text: instruction)])],
            generationConfig: .init(responseMimeType: "text/plain")
        )
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

