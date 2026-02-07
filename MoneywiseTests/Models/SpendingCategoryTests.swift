//
//  SpendingCategoryTests.swift
//  MoneywiseTests
//
//  Unit tests for the SpendingCategory model covering:
//  - Creating expense categories
//  - Creating income categories
//  - Emoji icon handling
//

import XCTest
import SwiftData
@testable import Moneywise

final class SpendingCategoryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
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

    // MARK: - testCreateExpenseCategory

    func testCreateExpenseCategory() throws {
        // Given: Expense category properties
        let categoryName = "Food & Dining"
        let categoryIcon = "🍔"
        let categoryColorHex = "#F97316"

        // When: Creating a new expense category
        let category = SpendingCategory(
            name: categoryName,
            icon: categoryIcon,
            colorHex: categoryColorHex,
            type: .expense
        )

        context.insert(category)
        try context.save()

        // Then: Category should be persisted with correct properties
        let descriptor = FetchDescriptor<SpendingCategory>()
        let categories = try context.fetch(descriptor)

        XCTAssertEqual(categories.count, 1, "Should have exactly one category")
        XCTAssertEqual(categories.first?.name, categoryName, "Category name should match")
        XCTAssertEqual(categories.first?.icon, categoryIcon, "Category icon should match")
        XCTAssertEqual(categories.first?.colorHex, categoryColorHex, "Category color hex should match")
        XCTAssertEqual(categories.first?.type, .expense, "Category type should be expense")
    }

    // MARK: - testCreateIncomeCategory

    func testCreateIncomeCategory() throws {
        // Given: Income category properties
        let categoryName = "Salary"
        let categoryIcon = "💵"
        let categoryColorHex = "#22C55E"

        // When: Creating a new income category
        let category = SpendingCategory(
            name: categoryName,
            icon: categoryIcon,
            colorHex: categoryColorHex,
            type: .income
        )

        context.insert(category)
        try context.save()

        // Then: Category should be persisted as income type
        let descriptor = FetchDescriptor<SpendingCategory>()
        let categories = try context.fetch(descriptor)

        XCTAssertEqual(categories.count, 1, "Should have exactly one category")
        XCTAssertEqual(categories.first?.name, categoryName, "Category name should match")
        XCTAssertEqual(categories.first?.type, .income, "Category type should be income")
    }

    // MARK: - testCategoryEmojiIcon

    func testCategoryEmojiIcon() throws {
        // Given: Multiple categories with emoji icons
        let expenseCategory = SpendingCategory(
            name: "Entertainment",
            icon: "🎬",
            colorHex: "#F59E0B",
            type: .expense
        )

        let incomeCategory = SpendingCategory(
            name: "Investment",
            icon: "📈",
            colorHex: "#14B8A6",
            type: .income
        )

        context.insert(expenseCategory)
        context.insert(incomeCategory)
        try context.save()

        // When: Fetching categories
        let descriptor = FetchDescriptor<SpendingCategory>()
        let categories = try context.fetch(descriptor)

        // Then: Emoji icons should be preserved
        XCTAssertEqual(categories.count, 2, "Should have two categories")

        let entertainment = categories.first { $0.name == "Entertainment" }
        let investment = categories.first { $0.name == "Investment" }

        XCTAssertNotNil(entertainment, "Should find Entertainment category")
        XCTAssertNotNil(investment, "Should find Investment category")

        XCTAssertEqual(entertainment?.icon, "🎬", "Entertainment icon should be preserved")
        XCTAssertEqual(investment?.icon, "📈", "Investment icon should be preserved")

        // Verify icons are valid emoji (non-empty strings)
        XCTAssertFalse(entertainment!.icon.isEmpty, "Icon should not be empty")
        XCTAssertFalse(investment!.icon.isEmpty, "Icon should not be empty")

        // Verify emoji count (typically 1-2 characters for standard emoji)
        XCTAssertLessThanOrEqual(entertainment!.icon.count, 2, "Standard emoji should be 1-2 characters")
    }
}
