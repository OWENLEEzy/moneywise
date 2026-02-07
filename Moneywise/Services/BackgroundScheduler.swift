//
//  BackgroundScheduler.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Background task scheduler for recurring transaction generation
//

import Foundation
import BackgroundTasks
import SwiftData
import OSLog

/// # BackgroundScheduler
///
/// ## Overview
/// Singleton service that manages background task registration and scheduling for
/// automatic recurring transaction generation. Uses iOS BackgroundTasks framework to
/// generate recurring transactions even when the app is not actively running.
///
/// ## Usage
/// ```swift
/// // Register during app launch
/// BackgroundScheduler.shared.register()
///
/// // Schedule background task
/// BackgroundScheduler.shared.schedule()
/// ```
///
/// ## How It Works
/// 1. App registers a background task with identifier "com.moneywise.generateRecurring"
/// 2. System wakes app in background (at least 1 hour after last run)
/// 3. Task handler fetches due recurring transactions and generates them
/// 4. Task reschedules itself for next run
///
/// ## Limitations
/// - Background execution time is limited (~30 seconds)
/// - System may defer execution based on user behavior and device conditions
/// - Minimum interval between executions is approximately 1 hour
/// - Not guaranteed to run at exact times
///
/// ## Thread Safety
/// This is a singleton with shared state. Not thread-safe but typically called
/// from main thread during app lifecycle events.
///
/// ## Dependencies
/// - BackgroundTasks: BGTaskScheduler for task registration and scheduling
/// - SwiftData: ModelContainer for accessing recurring transactions
/// - RecurringManager: Logic for generating due transactions
///
/// ## Configuration
/// - Task identifier: "com.moneywise.generateRecurring"
/// - Minimum interval: 1 hour (3600 seconds)
/// - Models required: Transaction, RecurringTransaction

/// Background task scheduler for recurring transaction generation
class BackgroundScheduler {
    static let shared = BackgroundScheduler()

    private let taskIdentifier = "com.moneywise.generateRecurring"
    private let logger = Logger(subsystem: "owenlee.Moneywise", category: "BackgroundScheduler")

    private init() {}

    /// Schedules the next background task execution
    ///
    /// Submits a task request to the system with a minimum begin date of 1 hour
    /// from now. The system may choose to run the task later based on various factors.
    ///
    /// - Note: Call this after app launch and after each task completion
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // At least 1 hour

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.debug("Background task scheduled")
        } catch {
            logger.error("Failed to schedule background task: \(error.localizedDescription)")
        }
    }

    /// Registers the background task handler with the system
    ///
    /// Must be called once during app launch (typically in `application(_:didFinishLaunchingWithOptions:)`).
    /// Registers the task identifier and provides a handler that will be called when
    /// the system wakes the app in the background.
    ///
    /// ## Handler Workflow
    /// 1. Schedule next task immediately (for continued operation)
    /// 2. Create SwiftData container for transaction access
    /// 3. Generate due recurring transactions
    /// 4. Mark task as completed
    ///
    /// - Important: Must be called before `schedule()` will work
    /// - Note: Task expiration is not explicitly handled; tasks should complete quickly
    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                self?.logger.warning("Background task is not BGAppRefreshTask type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleTask(appRefreshTask)
        }
    }

    /// Handles execution of a background task
    ///
    /// Creates a new SwiftData container, generates due recurring transactions,
    /// and marks the task as completed. Called by the system when the background
    /// task is triggered.
    ///
    /// - Parameter task: The background task to execute
    /// - Note: Creates its own ModelContainer since main context may not be available
    private func handleTask(_ task: BGAppRefreshTask) {
        // Schedule next task
        schedule()

        // Get model context
        let container = try? ModelContainer(
            for: Transaction.self,
            RecurringTransaction.self
        )
        guard let context = container?.mainContext else {
            task.setTaskCompleted(success: false)
            return
        }

        // Generate transactions
        let manager = RecurringManager(modelContext: context)
        let generated = manager.generateDueTransactions()

        logger.info("Generated \(generated) recurring transactions in background")

        task.setTaskCompleted(success: true)
    }
}
