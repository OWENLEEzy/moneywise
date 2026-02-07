//
//  GoalTests.swift
//  MoneywiseTests
//
//  Unit tests for the Goal model covering:
//  - Creating goals
//  - Progress calculation
//  - Goal completion detection
//  - Remaining amount calculation
//

import XCTest
import SwiftData
@testable import Moneywise

final class GoalTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            Goal.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - testCreateGoal

    func testCreateGoal() throws {
        // Given: Goal properties
        let goalName = "Emergency Fund"
        let targetAmount = Decimal(10000)
        let currentAmount = Decimal(2500)
        let deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let note = "Build 6 months of expenses"

        // When: Creating a new goal
        let goal = Goal(
            name: goalName,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: deadline,
            note: note
        )

        context.insert(goal)
        try context.save()

        // Then: Goal should be persisted with all properties
        let descriptor = FetchDescriptor<Goal>()
        let goals = try context.fetch(descriptor)

        XCTAssertEqual(goals.count, 1, "Should have exactly one goal")
        XCTAssertEqual(goals.first?.name, goalName, "Goal name should match")
        XCTAssertEqual(goals.first?.targetAmount, targetAmount, "Target amount should match")
        XCTAssertEqual(goals.first?.currentAmount, currentAmount, "Current amount should match")
        XCTAssertEqual(goals.first?.note, note, "Note should match")

        // Verify deadline is approximately correct (within 1 second)
        let timeDifference = abs(goals.first!.deadline.timeIntervalSince(deadline))
        XCTAssertLessThan(timeDifference, 1.0, "Deadline should match within 1 second")
    }

    // MARK: - testGoalProgress

    func testGoalProgress() throws {
        // Given: A goal with specific amounts
        let targetAmount = Decimal(5000)
        let currentAmount = Decimal(2500)

        let goal = Goal(
            name: "Vacation",
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating progress
        let progress = goal.progress

        // Then: Progress should be 50% (2500/5000)
        XCTAssertEqual(progress, 0.5, accuracy: 0.001, "Progress should be 0.5 (50%)")
    }

    func testGoalProgress_ZeroTarget() throws {
        // Given: A goal with zero target amount (edge case)
        let goal = Goal(
            name: "Invalid Goal",
            targetAmount: Decimal(0),
            currentAmount: Decimal(100),
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating progress with zero target
        let progress = goal.progress

        // Then: Progress should return 0 (safe guard)
        XCTAssertEqual(progress, 0, accuracy: 0.001, "Progress should be 0 for zero target amount")
    }

    func testGoalProgress_CappedAtOne() throws {
        // Given: A goal where current exceeds target
        let goal = Goal(
            name: "Overachiever",
            targetAmount: Decimal(1000),
            currentAmount: Decimal(1500),
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating progress when current > target
        let progress = goal.progress

        // Then: Progress should be capped at 1.0 (100%)
        XCTAssertEqual(progress, 1.0, accuracy: 0.001, "Progress should be capped at 1.0")
    }

    // MARK: - testGoalCompletion

    func testGoalCompletion() throws {
        // Given: A goal that's fully funded
        let goal = Goal(
            name: "New Laptop",
            targetAmount: Decimal(2000),
            currentAmount: Decimal(2000),
            deadline: Date()
        )

        context.insert(goal)

        // When: Checking progress
        let progress = goal.progress

        // Then: Goal should be complete (progress = 1.0)
        XCTAssertEqual(progress, 1.0, accuracy: 0.001, "Fully funded goal should have progress of 1.0")

        // Verify completion status via progress
        let isComplete = goal.progress >= 1.0
        XCTAssertTrue(isComplete, "Goal should be marked as complete")
    }

    func testGoalCompletion_NearCompletion() throws {
        // Given: A goal that's almost complete
        let goal = Goal(
            name: "Car Down Payment",
            targetAmount: Decimal(5000),
            currentAmount: Decimal(4950),
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating progress
        let progress = goal.progress

        // Then: Progress should be 99% but not complete
        XCTAssertEqual(progress, 0.99, accuracy: 0.001, "Progress should be 0.99")

        let isComplete = goal.progress >= 1.0
        XCTAssertFalse(isComplete, "Goal at 99% should not be marked as complete")
    }

    // MARK: - testGoalRemainingAmount

    func testGoalRemainingAmount() throws {
        // Given: A goal with specific amounts
        let targetAmount = Decimal(10000)
        let currentAmount = Decimal(3500)

        let goal = Goal(
            name: "Home Renovation",
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating remaining amount
        let remaining = goal.targetAmount - goal.currentAmount

        // Then: Remaining should be 6500
        XCTAssertEqual(remaining, Decimal(6500), "Remaining amount should be 6500")

        // Verify the calculation is correct
        let expectedRemaining = targetAmount - currentAmount
        XCTAssertEqual(remaining, expectedRemaining, "Remaining should equal target minus current")
    }

    func testGoalRemainingAmount_AtStart() throws {
        // Given: A new goal with no contributions
        let goal = Goal(
            name: "New Goal",
            targetAmount: Decimal(5000),
            currentAmount: Decimal(0),
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating remaining amount
        let remaining = goal.targetAmount - goal.currentAmount

        // Then: Remaining should equal target
        XCTAssertEqual(remaining, Decimal(5000), "Remaining should equal target at start")

        // Progress should be 0
        XCTAssertEqual(goal.progress, 0, accuracy: 0.001, "Progress should be 0 with no contributions")
    }

    func testGoalRemainingAmount_WhenOverTarget() throws {
        // Given: A goal that exceeded its target
        let goal = Goal(
            name: "Exceeded Goal",
            targetAmount: Decimal(1000),
            currentAmount: Decimal(1200),
            deadline: Date()
        )

        context.insert(goal)

        // When: Calculating remaining amount
        let remaining = goal.targetAmount - goal.currentAmount

        // Then: Remaining should be negative (overachiever)
        XCTAssertEqual(remaining, Decimal(-200), "Remaining should be negative when over target")

        // But progress should still be capped at 1.0
        XCTAssertEqual(goal.progress, 1.0, accuracy: 0.001, "Progress should cap at 1.0")
    }
}
