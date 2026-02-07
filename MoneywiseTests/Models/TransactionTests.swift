//
//  TransactionTests.swift
//  MoneywiseTests
//
//  Unit tests for the Transaction model covering:
//  - Creating transactions with various properties
//  - Transactions without categories
//  - Confidence scoring for AI-generated entries
//

import XCTest
import SwiftData
@testable import Moneywise

final class TransactionTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Transaction.self,
            SpendingCategory.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - testCreateTransaction

    func testCreateTransaction() throws {
        // Given: A category and transaction properties
        let category = SpendingCategory(name: "Food & Dining", icon: "🍔", colorHex: "#F97316", type: .expense)
        context.insert(category)

        let testAmount = Decimal(45.50)
        let testDate = Date()
        let testAccount = "Chase Checking"
        let testNote = "Lunch at cafe"

        // When: Creating a new transaction
        let transaction = Transaction(
            amount: testAmount,
            type: .expense,
            category: category,
            account: testAccount,
            date: testDate,
            note: testNote,
            paymentMethod: "Credit Card",
            isAIGenerated: false,
            confidence: 1.0
        )

        context.insert(transaction)
        try context.save()

        // Then: Transaction should be persisted with all properties
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1, "Should have exactly one transaction")
        XCTAssertEqual(transactions.first?.amount, testAmount, "Amount should match")
        XCTAssertEqual(transactions.first?.type, .expense, "Type should be expense")
        XCTAssertEqual(transactions.first?.category?.name, "Food & Dining", "Category name should match")
        XCTAssertEqual(transactions.first?.account, testAccount, "Account should match")
        XCTAssertEqual(transactions.first?.note, testNote, "Note should match")
        XCTAssertEqual(transactions.first?.paymentMethod, "Credit Card", "Payment method should match")
        XCTAssertFalse(transactions.first!.isAIGenerated, "Should not be AI generated")
        XCTAssertEqual(transactions.first?.confidence, 1.0, "Confidence should be 1.0")
    }

    // MARK: - testTransactionWithoutCategory

    func testTransactionWithoutCategory() throws {
        // Given: Transaction properties without a category
        let testAmount = Decimal(100.00)

        // When: Creating a transaction without a category
        let transaction = Transaction(
            amount: testAmount,
            type: .income,
            category: nil,
            account: "Savings",
            date: Date(),
            note: "Deposit"
        )

        context.insert(transaction)
        try context.save()

        // Then: Transaction should be created with nil category
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1, "Should have exactly one transaction")
        XCTAssertEqual(transactions.first?.amount, testAmount, "Amount should match")
        XCTAssertEqual(transactions.first?.type, .income, "Type should be income")
        XCTAssertNil(transactions.first?.category, "Category should be nil")
    }

    // MARK: - testTransactionConfidenceScore

    func testTransactionConfidenceScore() throws {
        // Given: A category for the transaction
        let category = SpendingCategory(name: "Transport", icon: "🚗", colorHex: "#3B82F6", type: .expense)
        context.insert(category)

        // When: Creating transactions with different confidence scores
        let highConfidenceTransaction = Transaction(
            amount: Decimal(30),
            type: .expense,
            category: category,
            account: "Cash",
            isAIGenerated: true,
            confidence: 0.95
        )

        let mediumConfidenceTransaction = Transaction(
            amount: Decimal(50),
            type: .expense,
            category: category,
            account: "Card",
            isAIGenerated: true,
            confidence: 0.75
        )

        context.insert(highConfidenceTransaction)
        context.insert(mediumConfidenceTransaction)
        try context.save()

        // Then: Confidence scores should be preserved
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        XCTAssertEqual(transactions.count, 2, "Should have two transactions")

        let high = transactions.first { $0.confidence > 0.9 }
        let medium = transactions.first { $0.confidence > 0.7 && $0.confidence < 0.8 }

        XCTAssertNotNil(high, "Should find high confidence transaction")
        XCTAssertNotNil(medium, "Should find medium confidence transaction")
        XCTAssertEqual(high?.confidence, 0.95, accuracy: 0.001, "High confidence should be 0.95")
        XCTAssertEqual(medium?.confidence, 0.75, accuracy: 0.001, "Medium confidence should be 0.75")
        XCTAssertTrue(high?.isAIGenerated ?? false, "High confidence transaction should be AI generated")
        XCTAssertTrue(medium?.isAIGenerated ?? false, "Medium confidence transaction should be AI generated")
    }

    // MARK: - testLowConfidenceTransaction

    func testLowConfidenceTransaction() throws {
        // Given: A low confidence threshold (e.g., 0.8)
        let lowConfidenceThreshold = 0.8

        // When: Creating a transaction with low confidence
        let category = SpendingCategory(name: "Shopping", icon: "🛍️", colorHex: "#EC4899", type: .expense)
        context.insert(category)

        let lowConfidenceTransaction = Transaction(
            amount: Decimal(150),
            type: .expense,
            category: category,
            account: "Credit Card",
            note: "Ambiguous purchase",
            isAIGenerated: true,
            confidence: 0.55
        )

        context.insert(lowConfidenceTransaction)
        try context.save()

        // Then: Low confidence transaction should require manual review
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try context.fetch(descriptor)

        XCTAssertEqual(transactions.count, 1, "Should have one transaction")
        XCTAssertEqual(transactions.first?.confidence, 0.55, accuracy: 0.001, "Confidence should be 0.55")

        // Verify that this transaction would be flagged for manual review
        let requiresManualReview = transactions.first!.confidence < lowConfidenceThreshold
        XCTAssertTrue(requiresManualReview, "Transaction with confidence < 0.8 should require manual review")
        XCTAssertTrue(transactions.first!.isAIGenerated, "Low confidence transaction should be AI generated")
        XCTAssertEqual(transactions.first!.note, "Ambiguous purchase", "Note should be preserved")
    }
}
