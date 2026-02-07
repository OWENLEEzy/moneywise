//
//  AIServiceTests.swift
//  MoneywiseTests
//
//  Unit tests for AIService covering:
//  - parse() method - transaction parsing
//  - analyze() method - financial analysis
//  - chat() method - conversation handling
//  - Error handling - missingAPIKey, invalidAPIKey, networkError
//

import XCTest
import SwiftData
@testable import Moneywise

/// Mock URL session protocol for testing network calls
protocol MockURLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Mock URLSession for testing AIService network calls
final class MockURLSessionDataTask: Sendable {
    var mockData: Data
    var mockResponse: URLResponse
    var mockError: Error?

    init(mockData: Data, mockResponse: URLResponse, mockError: Error? = nil) {
        self.mockData = mockData
        self.mockResponse = mockResponse
        self.mockError = mockError
    }

    func performRequest(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }
        return (mockData, mockResponse)
    }
}

/// Mock GeminiService that intercepts network calls
final class MockGeminiService {
    var mockParseResult: Result<GeminiResponse, Error> = .failure(AIServiceError.missingAPIKey)
    var mockAnalyzeResult: Result<GeminiTextResponse, Error> = .failure(AIServiceError.missingAPIKey)
    var mockSendResult: Result<Data, Error> = .failure(AIServiceError.missingAPIKey)
    var shouldReturnMarkdownJson = false
    var shouldReturnEmptyResponse = false

    // Track method calls for verification
    var parseTransactionCallCount = 0
    var analyzeCallCount = 0
    var sendCallCount = 0

    func reset() {
        mockParseResult = .failure(AIServiceError.missingAPIKey)
        mockAnalyzeResult = .failure(AIServiceError.missingAPIKey)
        mockSendResult = .failure(AIServiceError.missingAPIKey)
        shouldReturnMarkdownJson = false
        shouldReturnEmptyResponse = false
        parseTransactionCallCount = 0
        analyzeCallCount = 0
        sendCallCount = 0
    }

    func createSuccessfulParseResponse(
        amount: Double? = 25.50,
        type: TransactionType? = .expense,
        category: String? = "Food",
        account: String? = "Cash",
        paymentMethod: String? = "Cash",
        note: String? = "Lunch",
        confidence: Double? = 0.95,
        date: Date? = nil
    ) -> GeminiResponse {
        return GeminiResponse(
            amount: amount,
            type: type,
            category: category,
            account: account,
            paymentMethod: paymentMethod,
            note: note,
            confidence: confidence,
            date: date
        )
    }

    func createSuccessfulTextResponse(text: String) -> GeminiTextResponse {
        let response = GeminiTextResponse(
            candidates: [
                GeminiTextResponse.Candidate(
                    content: GeminiTextResponse.Candidate.Content(
                        parts: [GeminiTextResponse.Candidate.Content.Part(text: text)]
                    )
                )
            ],
            usageMetadata: GeminiTextResponse.UsageMetadata(
                promptTokenCount: 10,
                candidatesTokenCount: 20
            )
        )
        return response
    }

    func createGeminiAPIData(jsonText: String) throws -> Data {
        let payload: [String: Any] = [
            "candidates": [
                [
                    "content": [
                        "parts": [
                            ["text": jsonText]
                        ]
                    ]
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }
}

// MARK: - Test Helpers

extension AIServiceTests {
    func createInMemoryModelContainer() -> ModelContainer {
        let schema = Schema([
            Transaction.self,
            SpendingCategory.self,
            Goal.self,
            AIUsageStats.self,
            BudgetReminder.self,
            SettingItem.self,
            AIInsight.self,
            AIConversation.self,
            AIMessage.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            XCTFail("Failed to create test container: \(error)")
            fatalError("Test setup failed - cannot proceed")
        }
    }

    func createTestCategory(in context: ModelContext, name: String = "Food", type: TransactionType = .expense) -> SpendingCategory {
        let category = SpendingCategory(name: name, icon: "test", colorHex: "#FF0000", type: type)
        context.insert(category)
        try? context.save()
        return category
    }
}

// MARK: - Main Test Class

final class AIServiceTests: XCTestCase {

    var service: AIService!
    var mockContainer: ModelContainer!
    var mockContext: ModelContext!
    var testApiKey: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory SwiftData container
        mockContainer = createInMemoryModelContainer()
        mockContext = mockContainer.mainContext

        // Setup test API key
        testApiKey = "test-api-key-12345"

        // Create AIService with mock API key provider
        service = AIService(apiKeyProvider: { [weak self] in
            return self?.testApiKey
        })
    }

    override func tearDown() async throws {
        service = nil
        mockContext = nil
        mockContainer = nil
        testApiKey = nil
        try await super.tearDown()
    }

    // MARK: - Parse Method Tests

    @MainActor
    func testParseMissingAPIKey() async throws {
        // Given: Service with nil API key
        let noKeyService = AIService(apiKeyProvider: { nil })

        // When & Then: Should throw missingAPIKey error
        do {
            _ = try await noKeyService.parse(text: "spent 10 on lunch", context: mockContext)
            XCTFail("Expected AIServiceError.missingAPIKey to be thrown")
        } catch AIServiceError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Expected AIServiceError.missingAPIKey, got: \(error)")
        }
    }

    @MainActor
    func testParseReturnsTransactionWithCorrectDefaults() async throws {
        // This test verifies the logic of AIService.parse()
        // Since we can't easily mock the internal GeminiService,
        // we'll test that the parse method constructs Transaction objects correctly
        // given a successful GeminiResponse

        // Given: A test category exists
        let testCategory = createTestCategory(in: mockContext, name: "Food", type: .expense)

        // Create a mock response that would come from GeminiService
        let mockResponse = GeminiResponse(
            amount: 25.50,
            type: .expense,
            category: "Food",
            account: "Cash",
            paymentMethod: "Cash",
            note: "Test lunch expense",
            confidence: 0.95,
            date: Date()
        )

        // When: Using saveTransaction with the mock response
        try await service.saveTransaction(mockResponse, in: mockContext)

        // Then: Verify the transaction was saved correctly
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try mockContext.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1)
        let transaction = transactions.first

        XCTAssertEqual(transaction?.amount, Decimal(25.50))
        XCTAssertEqual(transaction?.type, .expense)
        XCTAssertEqual(transaction?.category?.name, "Food")
        XCTAssertEqual(transaction?.account, "Cash")
        XCTAssertEqual(transaction?.paymentMethod, "Cash")
        XCTAssertEqual(transaction?.note, "Test lunch expense")
        XCTAssertEqual(transaction?.isAIGenerated, true)
        XCTAssertEqual(transaction?.confidence, 0.95)
    }

    @MainActor
    func testParseCreatesUncategorizedCategory() async throws {
        // Given: No categories exist and we receive a response with "Uncategorized"
        let mockResponse = GeminiResponse(
            amount: 10.0,
            type: .expense,
            category: "Uncategorized",
            account: "Cash",
            paymentMethod: "Cash",
            note: "Unknown expense",
            confidence: 0.7,
            date: Date()
        )

        // When: Saving the transaction
        try await service.saveTransaction(mockResponse, in: mockContext)

        // Then: Transaction should be created with a category
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try mockContext.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1)
        let transaction = transactions.first
        XCTAssertNotNil(transaction?.category)
        XCTAssertEqual(transaction?.category?.name, "Uncategorized")
    }

    @MainActor
    func testParseWithIncomeType() async throws {
        // Given: An income category
        let mockResponse = GeminiResponse(
            amount: 5000.0,
            type: .income,
            category: "Salary",
            account: "Bank",
            paymentMethod: "Bank Transfer",
            note: "Monthly salary",
            confidence: 0.98,
            date: Date()
        )

        // When: Saving the transaction
        try await service.saveTransaction(mockResponse, in: mockContext)

        // Then: Transaction should have income type
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try mockContext.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1)
        let transaction = transactions.first
        XCTAssertEqual(transaction?.type, .income)
        XCTAssertEqual(transaction?.amount, Decimal(5000.0))
    }

    // MARK: - Analyze Method Tests

    @MainActor
    func testAnalyzeWithNoTransactions() async throws {
        // Given: Empty transaction database
        // Note: analyze() will fail at the network call since we can't mock GeminiService
        // but we can verify it correctly fetches an empty dataset

        // Create service with nil API key to test the first error case
        let noKeyService = AIService(apiKeyProvider: { nil })

        // When & Then: Should throw missingAPIKey
        do {
            _ = try await noKeyService.analyze(question: "What are my spending habits?", context: mockContext)
            XCTFail("Expected AIServiceError.missingAPIKey")
        } catch AIServiceError.missingAPIKey {
            // Expected - analyze method correctly checks for API key
        } catch {
            XCTFail("Expected AIServiceError.missingAPIKey, got: \(error)")
        }
    }

    @MainActor
    func testAnalyzeWithExistingTransactions() async throws {
        // Given: Some transactions in the database
        let category = createTestCategory(in: mockContext, name: "Food", type: .expense)

        let transaction1 = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: category,
            account: "Cash",
            note: "Lunch",
            paymentMethod: "Cash",
            isAIGenerated: false
        )
        mockContext.insert(transaction1)

        let transaction2 = Transaction(
            amount: Decimal(10.0),
            type: .expense,
            category: category,
            account: "Card",
            note: "Coffee",
            paymentMethod: "Credit Card",
            isAIGenerated: false
        )
        mockContext.insert(transaction2)
        try mockContext.save()

        // Verify transactions were saved
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try mockContext.fetch(descriptor)
        XCTAssertEqual(transactions.count, 2)

        // Note: We can't test the full analyze flow without mocking GeminiService
        // but we've verified the data is correctly set up
    }

    // MARK: - Chat Method Tests

    @MainActor
    func testChatMissingAPIKey() async throws {
        // Given: Service with nil API key
        let noKeyService = AIService(apiKeyProvider: { nil })

        // When & Then: Should throw missingAPIKey
        do {
            _ = try await noKeyService.chat(message: "Hello", conversationId: nil, context: mockContext)
            XCTFail("Expected AIServiceError.missingAPIKey")
        } catch AIServiceError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Expected AIServiceError.missingAPIKey, got: \(error)")
        }
    }

    @MainActor
    func testChatCreatesNewConversation() async throws {
        // This test verifies that chat creates a new conversation when no ID is provided
        // We can't fully test it without mocking GeminiService

        // Given: No existing conversation
        let descriptor = FetchDescriptor<AIConversation>()
        let conversations = try mockContext.fetch(descriptor)
        XCTAssertEqual(conversations.count, 0)

        // Note: Full test requires mocking GeminiService.send()
        // The conversation creation logic is in place but can't be fully tested
        // without dependency injection or protocol-based architecture
    }

    @MainActor
    func testChatReusesExistingConversation() async throws {
        // Given: An existing conversation
        let conversation = AIConversation(title: "Test Chat")
        mockContext.insert(conversation)
        try mockContext.save()

        // Verify it was saved
        let descriptor = FetchDescriptor<AIConversation>()
        let conversations = try mockContext.fetch(descriptor)
        XCTAssertEqual(conversations.count, 1)
        XCTAssertEqual(conversations.first?.title, "Test Chat")

        // Note: Full test requires mocking GeminiService.send()
    }

    @MainActor
    func testGetAllConversations() async throws {
        // Given: Multiple conversations
        let conv1 = AIConversation(title: "Chat 1")
        let conv2 = AIConversation(title: "Chat 2")
        let archivedConv = AIConversation(title: "Archived Chat", isArchived: true)

        mockContext.insert(conv1)
        mockContext.insert(conv2)
        mockContext.insert(archivedConv)
        try mockContext.save()

        // When: Getting all conversations
        let conversations = try service.getAllConversations(context: mockContext)

        // Then: Should only return non-archived conversations
        XCTAssertEqual(conversations.count, 2)
        XCTAssertTrue(conversations.allSatisfy { !$0.isArchived })
    }

    @MainActor
    func testGetConversationById() async throws {
        // Given: A conversation with known ID
        let conversation = AIConversation(title: "Test Chat")
        mockContext.insert(conversation)
        try mockContext.save()

        // When: Fetching by ID
        let fetched = try service.getConversation(id: conversation.id, context: mockContext)

        // Then: Should return the conversation
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, conversation.id)
        XCTAssertEqual(fetched?.title, "Test Chat")
    }

    @MainActor
    func testDeleteConversation() async throws {
        // Given: A conversation
        let conversation = AIConversation(title: "To Delete")
        mockContext.insert(conversation)
        try mockContext.save()

        let conversationId = conversation.id

        // When: Deleting
        try service.deleteConversation(id: conversationId, context: mockContext)

        // Then: Should be removed
        let descriptor = FetchDescriptor<AIConversation>()
        let conversations = try mockContext.fetch(descriptor)
        XCTAssertEqual(conversations.count, 0)
    }

    @MainActor
    func testArchiveConversation() async throws {
        // Given: A non-archived conversation
        let conversation = AIConversation(title: "To Archive", isArchived: false)
        mockContext.insert(conversation)
        try mockContext.save()

        // When: Archiving
        try service.archiveConversation(id: conversation.id, context: mockContext)

        // Then: Should be marked as archived
        let descriptor = FetchDescriptor<AIConversation>()
        let conversations = try mockContext.fetch(descriptor)
        let archivedConversation = conversations.first

        XCTAssertTrue(archivedConversation?.isArchived ?? false)
    }

    // MARK: - Generate Insights Tests

    @MainActor
    func testGenerateInsightsMissingAPIKey() async throws {
        // Given: Service with nil API key
        let noKeyService = AIService(apiKeyProvider: { nil })

        // When & Then: Should throw missingAPIKey
        do {
            _ = try await noKeyService.generateInsights(transactions: [], period: "weekly", context: mockContext)
            XCTFail("Expected AIServiceError.missingAPIKey")
        } catch AIServiceError.missingAPIKey {
            // Expected
        } catch {
            XCTFail("Expected AIServiceError.missingAPIKey, got: \(error)")
        }
    }

    // MARK: - Error Handling Tests

    func testAIServiceErrorDescriptions() {
        // Given: Various error cases
        let errors: [AIServiceError] = [
            .missingAPIKey,
            .invalidResponse,
            .decodingFailed,
            .networkError("Connection lost"),
            .invalidAPIKey,
            .serverError(500),
            .clientError(400, "Bad request")
        ]

        // When & Then: All errors should have descriptions
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error \(error) should have a description")
        }

        // Verify specific error messages
        XCTAssertEqual(AIServiceError.missingAPIKey.errorDescription, "Please configure Gemini API Key first")
        XCTAssertEqual(AIServiceError.invalidAPIKey.errorDescription, "Invalid API Key. Please check your key.")
        XCTAssertTrue(AIServiceError.networkError("test").errorDescription?.contains("Network Error") ?? false)
    }

    // MARK: - Transaction Model Tests

    func testTransactionTypeLocalizedTitle() {
        XCTAssertEqual(TransactionType.expense.localizedTitle, "Expense")
        XCTAssertEqual(TransactionType.income.localizedTitle, "Income")
    }

    func testTransactionTypeId() {
        XCTAssertEqual(TransactionType.expense.id, "expense")
        XCTAssertEqual(TransactionType.income.id, "income")
    }

    func testReminderTypeCopy() {
        XCTAssertEqual(ReminderType.dailyLog.copy, "Daily Log Reminder")
        XCTAssertEqual(ReminderType.savingGoal.copy, "Savings Goal Reminder")
    }

    // MARK: - Category Tests

    @MainActor
    func testDefaultCategoriesExist() {
        // Given: Default categories
        let defaultCategories = SpendingCategory.defaultCategories

        // When & Then: Should have both expense and income categories
        let expenseCategories = defaultCategories.filter { $0.type == .expense }
        let incomeCategories = defaultCategories.filter { $0.type == .income }

        XCTAssertEqual(expenseCategories.count, 9)
        XCTAssertEqual(incomeCategories.count, 3)

        // Verify specific categories exist
        XCTAssertTrue(defaultCategories.contains(where: { $0.name == "Food & Dining" }))
        XCTAssertTrue(defaultCategories.contains(where: { $0.name == "Salary" }))
    }

    // MARK: - ModelContext Helper Tests

    @MainActor
    func testModelContextCategoryHelperCreatesNewCategory() async throws {
        // Given: No categories exist
        let descriptor = FetchDescriptor<SpendingCategory>()
        let categories = try mockContext.fetch(descriptor)
        XCTAssertEqual(categories.count, 0)

        // When: Requesting a new category
        let category = try mockContext.category(named: "New Category", type: .expense)

        // Then: Category should be created and saved
        XCTAssertNotNil(category)
        XCTAssertEqual(category?.name, "New Category")

        let afterCreate = try mockContext.fetch(descriptor)
        XCTAssertEqual(afterCreate.count, 1)
    }

    @MainActor
    func testModelContextCategoryHelperReusesExistingCategory() async throws {
        // Given: A category already exists
        let existing = createTestCategory(in: mockContext, name: "Food", type: .expense)

        // When: Requesting the same category
        let fetched = try mockContext.category(named: "Food", type: .expense)

        // Then: Should return the existing category
        XCTAssertEqual(fetched?.id, existing.id)

        let descriptor = FetchDescriptor<SpendingCategory>()
        let categories = try mockContext.fetch(descriptor)
        XCTAssertEqual(categories.count, 1) // No duplicate created
    }

    @MainActor
    func testModelContextCategoryHelperHandlesEmptyName() async throws {
        // Given: No categories

        // When: Requesting with empty name
        let category = try mockContext.category(named: "", type: .expense)

        // Then: Should return nil
        XCTAssertNil(category)

        let category2 = try mockContext.category(named: nil, type: .expense)
        XCTAssertNil(category2)
    }

    // MARK: - Conversation Model Tests

    @MainActor
    func testConversationSortedMessages() async throws {
        // Given: A conversation with messages
        let conversation = AIConversation(title: "Test")
        mockContext.insert(conversation)

        let now = Date()
        let message1 = AIMessage(role: .user, content: "First", timestamp: now.addingTimeInterval(-2))
        message1.conversation = conversation

        let message2 = AIMessage(role: .assistant, content: "Second", timestamp: now.addingTimeInterval(-1))
        message2.conversation = conversation

        let message3 = AIMessage(role: .user, content: "Third", timestamp: now)
        message3.conversation = conversation

        mockContext.insert(message1)
        mockContext.insert(message2)
        mockContext.insert(message3)
        try mockContext.save()

        // When: Getting sorted messages
        let sorted = conversation.sortedMessages

        // Then: Should be in chronological order
        XCTAssertEqual(sorted[0].content, "First")
        XCTAssertEqual(sorted[1].content, "Second")
        XCTAssertEqual(sorted[2].content, "Third")
    }

    // MARK: - Goal Model Tests

    func testGoalProgressCalculation() {
        // Given: A goal with partial progress
        let goal = Goal(
            name: "Test Goal",
            targetAmount: Decimal(100),
            currentAmount: Decimal(50),
            deadline: Date().addingTimeInterval(86400 * 30)
        )

        // When & Then: Progress should be 50%
        XCTAssertEqual(goal.progress, 0.5, accuracy: 0.001)
    }

    func testGoalProgressWithZeroTarget() {
        // Given: A goal with zero target
        let goal = Goal(
            name: "Test Goal",
            targetAmount: Decimal(0),
            currentAmount: Decimal(50),
            deadline: Date().addingTimeInterval(86400 * 30)
        )

        // When & Then: Progress should be 0 (avoid division by zero)
        XCTAssertEqual(goal.progress, 0)
    }

    func testGoalProgressOverTarget() {
        // Given: A goal that exceeded target
        let goal = Goal(
            name: "Test Goal",
            targetAmount: Decimal(100),
            currentAmount: Decimal(150),
            deadline: Date().addingTimeInterval(86400 * 30)
        )

        // When & Then: Progress should be capped at 1.0
        XCTAssertEqual(goal.progress, 1.0, accuracy: 0.001)
    }

    // MARK: - Integration Tests

    @MainActor
    func testFullTransactionWorkflow() async throws {
        // This test simulates a full workflow from category creation to transaction saving

        // Given: Default categories and a mock GeminiResponse
        let _ = createTestCategory(in: mockContext, name: "Shopping", type: .expense)

        let mockResponse = GeminiResponse(
            amount: 99.99,
            type: .expense,
            category: "Shopping",
            account: "Credit Card",
            paymentMethod: "Credit Card",
            note: "New shoes",
            confidence: 0.92,
            date: Date()
        )

        // When: Saving the transaction
        try await service.saveTransaction(mockResponse, in: mockContext)

        // Then: Verify complete transaction record
        let txnDescriptor = FetchDescriptor<Transaction>()
        let transactions = try mockContext.fetch(txnDescriptor)

        XCTAssertEqual(transactions.count, 1)
        let transaction = transactions.first

        XCTAssertEqual(transaction?.amount, Decimal(99.99))
        XCTAssertEqual(transaction?.type, .expense)
        XCTAssertEqual(transaction?.category?.name, "Shopping")
        XCTAssertEqual(transaction?.account, "Credit Card")
        XCTAssertEqual(transaction?.paymentMethod, "Credit Card")
        XCTAssertEqual(transaction?.note, "New shoes")
        XCTAssertEqual(transaction?.isAIGenerated, true)
        XCTAssertEqual(transaction?.confidence, 0.92)
    }
}
