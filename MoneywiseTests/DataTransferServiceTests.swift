import XCTest
import SwiftData
@testable import Moneywise

/// Unit tests for DataTransferService (CSVService)
///
/// Tests cover:
/// - CSV export functionality
/// - CSV import functionality
/// - Deduplication logic
/// - Error handling for malformed CSV
/// - Edge cases and boundary conditions
final class DataTransferServiceTests: XCTestCase {

    // MARK: - Properties

    private var csvService: CSVService!
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create in-memory SwiftData container for isolated testing
        let schema = Schema([
            Transaction.self,
            SpendingCategory.self,
            Goal.self,
            AIUsageStats.self,
            AIInsight.self,
            BudgetReminder.self,
            SettingItem.self,
            AIConversation.self,
            AIMessage.self
        ])

        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)

        // Initialize CSVService
        csvService = CSVService()

        // Bootstrap default categories for testing
        bootstrapDefaultCategories()
    }

    override func tearDown() async throws {
        csvService = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates test transactions with various attributes
    private func createTestTransactions() -> [Transaction] {
        let foodCategory = try? modelContext.category(named: "Food & Dining", type: .expense)
        let transportCategory = try? modelContext.category(named: "Transport", type: .expense)
        let salaryCategory = try? modelContext.category(named: "Salary", type: .income)

        return [
            Transaction(
                amount: Decimal(25.50),
                type: .expense,
                category: foodCategory,
                account: "Credit Card",
                date: Date(timeIntervalSince1970: 1704067200), // 2024-01-01 00:00:00
                note: "Lunch at cafe",
                paymentMethod: "Credit Card",
                isAIGenerated: true,
                confidence: 0.95
            ),
            Transaction(
                amount: Decimal(15.00),
                type: .expense,
                category: foodCategory,
                account: "Cash",
                date: Date(timeIntervalSince1970: 1704153600), // 2024-01-02 00:00:00
                note: "Coffee",
                paymentMethod: "Cash",
                isAIGenerated: false,
                confidence: 1.0
            ),
            Transaction(
                amount: Decimal(3500.00),
                type: .income,
                category: salaryCategory,
                account: "Bank Account",
                date: Date(timeIntervalSince1970: 1704240000), // 2024-01-03 00:00:00
                note: "Monthly salary",
                paymentMethod: "Direct Deposit",
                isAIGenerated: false,
                confidence: 1.0
            ),
            Transaction(
                amount: Decimal(45.00),
                type: .expense,
                category: transportCategory,
                account: "Credit Card",
                date: Date(timeIntervalSince1970: 1704326400), // 2024-01-04 00:00:00
                note: "Gas refill",
                paymentMethod: "Credit Card",
                isAIGenerated: true,
                confidence: 0.85
            )
        ]
    }

    /// Creates a test CSV file from content string
    private func createTestCSVFile(content: String) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).csv")
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    /// Bootstraps default categories into the model context
    private func bootstrapDefaultCategories() {
        for category in SpendingCategory.defaultCategories {
            modelContext.insert(category)
        }
        try? modelContext.save()
    }

    /// Fetches all transactions from the context
    private func fetchAllTransactions() throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>()
        return try modelContext.fetch(descriptor)
    }

    // MARK: - CSV Export Tests

    func testExport_EmptyTransactionList() throws {
        // Given: An empty transaction list
        let transactions: [Transaction] = []

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: transactions)

        // Then: File should be created with header only
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("date,amount,category,type,note,account,is_ai_generated"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testExport_SingleTransaction() throws {
        // Given: A single transaction
        let foodCategory = try? modelContext.category(named: "Food & Dining", type: .expense)
        let transaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: foodCategory,
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200),
            note: "Lunch at cafe",
            isAIGenerated: true
        )

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: [transaction])

        // Then: File should contain header and one data row
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 2, "Should have header and one data row")
        XCTAssertTrue(lines[0].contains("date,amount,category"))
        XCTAssertTrue(lines[1].contains("25.5"))
        XCTAssertTrue(lines[1].contains("expense"))
        XCTAssertTrue(lines[1].contains("Lunch at cafe"))
        XCTAssertTrue(lines[1].contains("true"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testExport_MultipleTransactions() throws {
        // Given: Multiple transactions
        let transactions = createTestTransactions()

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: transactions)

        // Then: File should contain all transactions
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 5, "Should have header plus 4 data rows")
        XCTAssertTrue(content.contains("25.5"))
        XCTAssertTrue(content.contains("15"))
        XCTAssertTrue(content.contains("3500"))
        XCTAssertTrue(content.contains("45"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testExport_TransactionWithoutCategory() throws {
        // Given: A transaction without a category
        let transaction = Transaction(
            amount: Decimal(100),
            type: .expense,
            category: nil,
            account: "Cash",
            date: Date(),
            note: "Uncategorized expense",
            isAIGenerated: false
        )

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: [transaction])

        // Then: Category should be "Uncategorized"
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Uncategorized"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testExport_TransactionWithSpecialCharactersInNote() throws {
        // Given: A transaction with special characters in note
        let transaction = Transaction(
            amount: Decimal(50),
            type: .expense,
            category: nil,
            account: "Cash",
            date: Date(),
            note: "Lunch with comma, and \"quotes\"",
            isAIGenerated: false
        )

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: [transaction])

        // Then: Special characters should be properly handled
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("Lunch with comma, and"), "Note should contain the comma")
        XCTAssertTrue(content.contains("quotes"), "Note should contain the quoted text")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testExport_FileCreationInTemporaryDirectory() throws {
        // Given: Some transactions
        let transactions = createTestTransactions()

        // When: Exporting to CSV
        let fileURL = try csvService.export(transactions: transactions)

        // Then: File should exist in temporary directory
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(fileURL.path.contains(FileManager.default.temporaryDirectory.path))
        XCTAssertTrue(fileURL.pathExtension == "csv")
        XCTAssertTrue(fileURL.lastPathComponent.hasPrefix("Moneywise-"))

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - CSV Import Tests

    func testImport_ValidCSV_ImportAllStrategy() throws {
        // Given: A valid CSV file
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with importAll strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: All rows should be imported
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.count, 2)

        // Verify first transaction
        let first = transactions.first { $0.note == "Lunch" }
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.amount, Decimal(25.5))
        XCTAssertEqual(first?.account, "Credit Card")
        XCTAssertTrue(first?.isAIGenerated ?? false)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_ValidCSV_SkipDuplicatesStrategy() throws {
        // Given: Existing transaction in database and a CSV with duplicate
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200), // 2024-01-01 12:00:00 UTC
            note: "Lunch",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with skipDuplicates strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .skipDuplicates)

        // Then: Duplicate should be skipped, new one imported
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.count, 2, "Should have original + 1 new import")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_InvalidDate_ShouldSkipRow() throws {
        // Given: CSV with invalid date
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        invalid-date,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Invalid row should be skipped
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.note, "Coffee")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_InvalidAmount_ShouldSkipRow() throws {
        // Given: CSV with invalid amount
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,not-a-number,"Food & Dining",expense,"Lunch","Credit Card",true
        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Invalid row should be skipped
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_MissingColumns_ShouldSkipRow() throws {
        // Given: CSV with insufficient columns
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch"
        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Row with missing columns should be skipped
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 1)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_UnknownTransactionType_ShouldDefaultToExpense() throws {
        // Given: CSV with unknown transaction type
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",unknown_type,"Lunch","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Should default to expense type
        XCTAssertEqual(result.imported, 1)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.first?.type, .expense)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testImport_NewCategoryCreated() throws {
        // Given: CSV with a new category
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,100.00,"Custom Category",expense,"Custom expense","Cash",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: New category should be created
        XCTAssertEqual(result.imported, 1)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.first?.category?.name, "Custom Category")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Deduplication Tests

    func testDeduplication_ExactMatch_Skipped() throws {
        // Given: Existing transaction
        let existingDate = Date(timeIntervalSince1970: 1704067200)
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: existingDate,
            note: "Lunch",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with skipDuplicates strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .skipDuplicates)

        // Then: Duplicate should be skipped
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skipped, 1)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.count, 1, "Should only have the original transaction")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testDeduplication_DifferentAmount_NotSkipped() throws {
        // Given: Existing transaction
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200),
            note: "Lunch",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,30.00,"Food & Dining",expense,"Lunch","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with skipDuplicates strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .skipDuplicates)

        // Then: Should not be considered duplicate (different amount)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testDeduplication_DifferentNote_NotSkipped() throws {
        // Given: Existing transaction
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200),
            note: "Lunch at cafe",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Dinner","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with skipDuplicates strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .skipDuplicates)

        // Then: Should not be considered duplicate (different note)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testDeduplication_DifferentDate_NotSkipped() throws {
        // Given: Existing transaction
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200), // 2024-01-01
            note: "Lunch",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-02T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with skipDuplicates strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .skipDuplicates)

        // Then: Should not be considered duplicate (different date)
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testDeduplication_ImportAllStrategy_NoSkipping() throws {
        // Given: Existing transaction
        let existingTransaction = Transaction(
            amount: Decimal(25.50),
            type: .expense,
            category: try? modelContext.category(named: "Food & Dining", type: .expense),
            account: "Credit Card",
            date: Date(timeIntervalSince1970: 1704067200),
            note: "Lunch",
            isAIGenerated: true
        )
        modelContext.insert(existingTransaction)
        try modelContext.save()

        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing with importAll strategy
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Duplicate should NOT be skipped
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skipped, 0)

        let transactions = try fetchAllTransactions()
        XCTAssertEqual(transactions.count, 2, "Should have both original and imported")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Error Handling Tests

    func testImport_EmptyFile_ThrowsError() {
        // Given: An empty CSV file
        let csvContent = ""

        do {
            let fileURL = try createTestCSVFile(content: csvContent)

            // When/Then: Importing should throw error
            XCTAssertThrowsError(try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)) { error in
                XCTAssertTrue(error is CSVServiceError)
                XCTAssertEqual(error as? CSVServiceError, .invalidFormat)
            }

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }

    func testImport_MissingHeader_ThrowsError() {
        // Given: CSV without proper header
        let csvContent = """
        wrong,header,format
        some,data,here
        """

        do {
            let fileURL = try createTestCSVFile(content: csvContent)

            // When/Then: Importing should throw error
            XCTAssertThrowsError(try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)) { error in
                XCTAssertTrue(error is CSVServiceError)
                XCTAssertEqual(error as? CSVServiceError, .invalidFormat)
            }

            // Cleanup
            try? FileManager.default.removeItem(at: fileURL)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }
    }

    func testImport_InvalidUTF8Encoding_ThrowsError() {
        // Given: A file with invalid UTF-8 content
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).csv")

        // Write invalid UTF-8 data
        let invalidData = Data([0xFF, 0xFE, 0xFD]) // Invalid UTF-8 sequence
        try? invalidData.write(to: tempURL)

        // When/Then: Importing should throw error
        XCTAssertThrowsError(try csvService.import(url: tempURL, context: modelContext, strategy: .importAll)) { error in
            XCTAssertTrue(error is CSVServiceError)
            XCTAssertEqual(error as? CSVServiceError, .invalidFormat)
        }

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testImport_NonExistentFile_ThrowsError() {
        // Given: A non-existent file URL
        let nonExistentURL = URL(fileURLWithPath: "/path/that/does/not/exist.csv")

        // When/Then: Importing should throw error (not CSVServiceError, but foundation error)
        XCTAssertThrowsError(try csvService.import(url: nonExistentURL, context: modelContext, strategy: .importAll))
    }

    // MARK: - CSV Parsing Tests

    func testParseColumns_WithQuotedFields() throws {
        // Given: CSV with quoted fields containing commas
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,25.50,"Food, Dining, & Drinks",expense,"Lunch with extra, comma","Credit Card",true
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Should correctly parse quoted fields with commas
        XCTAssertEqual(result.imported, 1)

        let transactions = try fetchAllTransactions()
        let transaction = transactions.first

        // Category name should preserve the comma
        XCTAssertEqual(transaction?.category?.name, "Food, Dining, & Drinks")

        // Note should preserve the comma
        XCTAssertEqual(transaction?.note, "Lunch with extra, comma")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testParseColumns_EmptyLinesIgnored() throws {
        // Given: CSV with empty lines
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated

        2024-01-01T12:00:00,25.50,"Food & Dining",expense,"Lunch","Credit Card",true

        2024-01-02T12:00:00,15.00,"Food & Dining",expense,"Coffee","Cash",false

        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Empty lines should be ignored
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Round Trip Tests

    func testRoundTrip_ExportThenImport() throws {
        // Given: Some transactions
        let originalTransactions = createTestTransactions()
        for transaction in originalTransactions {
            modelContext.insert(transaction)
        }
        try modelContext.save()

        // When: Exporting and then importing
        let exportedURL = try csvService.export(transactions: originalTransactions)

        // Clear the context
        let descriptor = FetchDescriptor<Transaction>()
        let allTransactions = try modelContext.fetch(descriptor)
        for transaction in allTransactions {
            modelContext.delete(transaction)
        }
        try modelContext.save()

        // Import into fresh context
        let result = try csvService.import(url: exportedURL, context: modelContext, strategy: .importAll)

        // Then: Should import all original transactions
        XCTAssertEqual(result.imported, 4)

        let importedTransactions = try fetchAllTransactions()
        XCTAssertEqual(importedTransactions.count, 4)

        // Verify amounts match
        let amounts = importedTransactions.map { $0.amount }.sorted()
        let expectedAmounts = [Decimal(15), Decimal(25.5), Decimal(45), Decimal(3500)].sorted()
        XCTAssertEqual(amounts, expectedAmounts)

        // Cleanup
        try? FileManager.default.removeItem(at: exportedURL)
    }

    // MARK: - Performance Tests

    func testPerformance_ExportLargeDataset() throws {
        // Given: A large number of transactions (1000)
        let foodCategory = try? modelContext.category(named: "Food & Dining", type: .expense)
        var transactions: [Transaction] = []

        for i in 0..<1000 {
            let transaction = Transaction(
                amount: Decimal(Double.random(in: 1...100)),
                type: .expense,
                category: foodCategory,
                account: "Credit Card",
                date: Date(timeIntervalSince1970: TimeInterval(1704067200 + i * 86400)),
                note: "Transaction \(i)",
                isAIGenerated: i % 2 == 0
            )
            transactions.append(transaction)
        }

        // Measure export performance
        measure {
            do {
                let fileURL = try csvService.export(transactions: transactions)
                try? FileManager.default.removeItem(at: fileURL)
            } catch {
                XCTFail("Export failed: \(error)")
            }
        }
    }

    func testPerformance_ImportLargeDataset() throws {
        // Given: A CSV with many rows (500)
        var lines = ["date,amount,category,type,note,account,is_ai_generated"]
        let foodCategory = try? modelContext.category(named: "Food & Dining", type: .expense)

        for i in 0..<500 {
            let date = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(1704067200 + i * 86400)))
            let line = "\(date),\(Double.random(in: 1...100)),\"Food & Dining\",expense,\"Transaction \(i)\","Credit Card",\(i % 2 == 0)"
            lines.append(line)
        }

        let csvContent = lines.joined(separator: "\n")
        let fileURL = try createTestCSVFile(content: csvContent)

        // Measure import performance
        measure {
            do {
                // Create fresh context for each measurement
                let schema = Schema([Transaction.self, SpendingCategory.self])
                let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
                let context = ModelContext(container)

                // Add default category
                context.insert(foodCategory!)
                try context.save()

                _ = try csvService.import(url: fileURL, context: context, strategy: .importAll)
            } catch {
                XCTFail("Import failed: \(error)")
            }
        }

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Income Transaction Tests

    func testImport_IncomeTransaction() throws {
        // Given: CSV with income transaction
        let csvContent = """
        date,amount,category,type,note,account,is_ai_generated
        2024-01-01T12:00:00,5000.00,"Salary",income,"Monthly salary","Bank Account",false
        """

        let fileURL = try createTestCSVFile(content: csvContent)

        // When: Importing
        let result = try csvService.import(url: fileURL, context: modelContext, strategy: .importAll)

        // Then: Income transaction should be created
        XCTAssertEqual(result.imported, 1)

        let transactions = try fetchAllTransactions()
        let transaction = transactions.first

        XCTAssertEqual(transaction?.type, .income)
        XCTAssertEqual(transaction?.amount, Decimal(5000))
        XCTAssertEqual(transaction?.category?.name, "Salary")

        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
}
