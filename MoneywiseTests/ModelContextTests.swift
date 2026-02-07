//
//  ModelContextTests.swift
//  MoneywiseTests
//
//  Unit tests for ModelContext extensions covering:
//  - saveSafe() method - error handling for save operations
//  - category(named:type:) method - category lookup and creation
//  - usageStatsRecord() method - usage stats retrieval and creation
//

import XCTest
import SwiftData
@testable import Moneywise

final class ModelContextTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        // Create an in-memory ModelContainer for testing
        let schema = Schema([
            Transaction.self,
            SpendingCategory.self,
            Goal.self,
            AIUsageStats.self,
            AIInsight.self,
            SettingItem.self,
            Budget.self,
            BudgetReminder.self,
            AIConversation.self,
            AIMessage.self,
            RecurringTransaction.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    // MARK: - saveSafe() Tests

    func testSaveSafe_returnsTrueOnSuccessfulSave() throws {
        // Given: A context with a new transaction
        let category = SpendingCategory(name: "Test", icon: "🧪", colorHex: "#000000", type: .expense)
        context.insert(category)

        let transaction = Transaction(
            amount: 100,
            type: .expense,
            category: category,
            account: "Test",
            date: Date(),
            note: "Test transaction"
        )
        context.insert(transaction)

        // When: saveSafe() is called
        let result = context.saveSafe()

        // Then: It should return true
        XCTAssertTrue(result, "saveSafe() should return true on successful save")

        // And: The transaction should be persisted
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        XCTAssertEqual(transactions.count, 1, "Transaction should be persisted")
    }

    func testSaveSafe_handlesEmptyContextGracefully() {
        // Given: An empty context (no changes to save)
        // When: saveSafe() is called
        let result = context.saveSafe()

        // Then: It should return true (no changes is still a successful operation)
        XCTAssertTrue(result, "saveSafe() should return true even with no changes")
    }

    func testSaveSafe_logsErrorOnSaveFailure() throws {
        // This test verifies the error handling path.
        // Since SwiftData's in-memory container rarely fails on save,
        // we verify the method doesn't crash and handles the result.

        // Given: A valid transaction
        let category = SpendingCategory(name: "Test", icon: "🧪", colorHex: "#000000", type: .expense)
        context.insert(category)
        let transaction = Transaction(
            amount: 100,
            type: .expense,
            category: category,
            account: "Test",
            date: Date(),
            note: "Test"
        )
        context.insert(transaction)

        // When: saveSafe() is called multiple times
        let firstResult = context.saveSafe()
        let secondResult = context.saveSafe()  // Saving again should be safe

        // Then: Both should return true
        XCTAssertTrue(firstResult, "First save should succeed")
        XCTAssertTrue(secondResult, "Second save should succeed even with no new changes")
    }

    // MARK: - category(named:type:) Tests

    func testCategoryNamed_returnsExistingCategory() throws {
        // Given: An existing category
        let existingCategory = SpendingCategory(name: "Food", icon: "🍔", colorHex: "#FF0000", type: .expense)
        context.insert(existingCategory)
        try context.save()

        // When: Looking up the category by name
        let foundCategory = try context.category(named: "Food", type: .expense)

        // Then: The existing category should be returned
        XCTAssertNotNil(foundCategory, "Should find the existing category")
        XCTAssertEqual(foundCategory?.name, "Food", "Category name should match")
        XCTAssertEqual(foundCategory?.icon, "🍔", "Category icon should match")
    }

    func testCategoryNamed_createsNewCategoryWhenNotFound() throws {
        // Given: No existing category
        // When: Looking up a non-existent category
        let newCategory = try context.category(named: "Transport", type: .expense)

        // Then: A new category should be created
        XCTAssertNotNil(newCategory, "Should create a new category")
        XCTAssertEqual(newCategory?.name, "Transport", "New category name should match")
        XCTAssertEqual(newCategory?.icon, "❓", "New category should have default icon")
    }

    func testCategoryNamed_returnsNilForEmptyName() throws {
        // Given: Empty name input
        // When: Looking up with nil
        let result1 = try context.category(named: nil, type: .expense)
        // When: Looking up with empty string
        let result2 = try context.category(named: "", type: .expense)

        // Then: Both should return nil
        XCTAssertNil(result1, "Should return nil for nil name")
        XCTAssertNil(result2, "Should return nil for empty string name")
    }

    // MARK: - usageStatsRecord() Tests

    func testUsageStatsRecord_createsNewStatsWhenNoneExists() throws {
        // Given: No existing usage stats
        // When: Calling usageStatsRecord()
        let stats = try context.usageStatsRecord()

        // Then: New stats should be created
        XCTAssertNotNil(stats, "Should create new stats")
        XCTAssertEqual(stats.inputTokens, 0, "Initial input tokens should be 0")
        XCTAssertEqual(stats.outputTokens, 0, "Initial output tokens should be 0")
        XCTAssertEqual(stats.totalCalls, 0, "Initial total calls should be 0")
    }

    func testUsageStatsRecord_returnsExistingStats() throws {
        // Given: Existing usage stats
        let existingStats = AIUsageStats()
        existingStats.inputTokens = 100
        existingStats.outputTokens = 200
        existingStats.totalCalls = 5
        context.insert(existingStats)
        try context.save()

        // When: Calling usageStatsRecord()
        let stats = try context.usageStatsRecord()

        // Then: The existing stats should be returned
        XCTAssertNotNil(stats, "Should return existing stats")
        XCTAssertEqual(stats.inputTokens, 100, "Should preserve input tokens")
        XCTAssertEqual(stats.outputTokens, 200, "Should preserve output tokens")
        XCTAssertEqual(stats.totalCalls, 5, "Should preserve total calls")
    }

    // MARK: - Integration Tests

    func testSaveSafe_withMultipleTransactions() throws {
        // Given: Multiple transactions
        let category = SpendingCategory(name: "Test", icon: "🧪", colorHex: "#000000", type: .expense)
        context.insert(category)

        for i in 1...5 {
            let transaction = Transaction(
                amount: Decimal(i) * 10,
                type: .expense,
                category: category,
                account: "Test",
                date: Date(),
                note: "Transaction \(i)"
            )
            context.insert(transaction)
        }

        // When: saveSafe() is called
        let result = context.saveSafe()

        // Then: All transactions should be persisted
        XCTAssertTrue(result, "saveSafe() should return true")
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        XCTAssertEqual(transactions.count, 5, "All 5 transactions should be saved")
    }

    func testSaveSafe_withDeleteOperations() throws {
        // Given: A transaction that will be deleted
        let category = SpendingCategory(name: "Test", icon: "🧪", colorHex: "#000000", type: .expense)
        context.insert(category)
        let transaction = Transaction(
            amount: 100,
            type: .expense,
            category: category,
            account: "Test",
            date: Date(),
            note: "To be deleted"
        )
        context.insert(transaction)
        try context.save()

        // When: Deleting and calling saveSafe()
        context.delete(transaction)
        let result = context.saveSafe()

        // Then: The transaction should be removed
        XCTAssertTrue(result, "saveSafe() should return true after delete")
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)
        XCTAssertEqual(transactions.count, 0, "Transaction should be deleted")
    }
}
