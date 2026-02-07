//
//  MoneywiseApp.swift
//  Moneywise
//
//  Created by Owen Lee Zhao Yi on 20/11/2025.
//

import SwiftUI
import SwiftData
import CloudKit
import BackgroundTasks
import OSLog

@main
struct MoneywiseApp: App {
    @State private var persistenceController = PersistenceController.shared
    @State private var deeplinkRouter = DeeplinkRouter()
    @State private var syncStatusMonitor = SyncStatusMonitor()
    @State private var recurringManager: RecurringManager?
    @State private var appTheme = AppTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, persistenceController.container.mainContext)
                .environment(\.managedGoals, GoalManager(context: persistenceController.container.mainContext))
                .environment(\.aiConfiguration, AIConfigurationStore(context: persistenceController.container.mainContext))
                .environment(\.deeplinkRouter, deeplinkRouter)
                .environment(\.syncStatus, syncStatusMonitor)
                .environment(\.recurringManager, recurringManager)
                .environment(\.appTheme, appTheme)
                .task {
                    await persistenceController.bootstrap()
                    // Initialize recurring manager after bootstrap
                    recurringManager = RecurringManager(modelContext: persistenceController.container.mainContext)

                    // Register and schedule background task for recurring transactions
                    BackgroundScheduler.shared.register()
                    BackgroundScheduler.shared.schedule()
                }
        }
        .modelContainer(persistenceController.container)
        .cloudKitSyncMonitor(syncStatusMonitor)
    }
}

// MARK: - Persistence

private let logger = Logger(subsystem: "owenlee.Moneywise", category: "MoneywiseApp")

@Observable final class PersistenceController {
    static let shared = PersistenceController()
    let container: ModelContainer

    // CloudKit container identifier - must match the one in Apple Developer Portal
    // Format: iCloud.<bundle_id> (e.g., iCloud.owenlee.Moneywise)
    private static let cloudKitContainerIdentifier = "iCloud.owenlee.Moneywise"

    private init(inMemory: Bool = false) {
        do {
            // Create CloudKit configuration for sync
            let cloudKitConfiguration = ModelConfiguration(
                identifier: "MoneywiseCloudKit",
                cloudKitDatabase: .automatic
            )

            // Initialize with CloudKit support
            if inMemory {
                container = try ModelContainer(
                    for: Transaction.self,
                    SpendingCategory.self,
                    Budget.self,
                    BudgetReminder.self,
                    Goal.self,
                    AIUsageStats.self,
                    AIInsight.self,
                    SettingItem.self,
                    AIConversation.self,
                    AIMessage.self,
                    RecurringTransaction.self,
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            } else {
                container = try ModelContainer(
                    for: Transaction.self,
                    SpendingCategory.self,
                    Budget.self,
                    BudgetReminder.self,
                    Goal.self,
                    AIUsageStats.self,
                    AIInsight.self,
                    SettingItem.self,
                    AIConversation.self,
                    AIMessage.self,
                    RecurringTransaction.self,
                    configurations: cloudKitConfiguration
                )
            }
        } catch {
            // Fallback to local-only if CloudKit initialization fails
            do {
                container = try ModelContainer(
                    for: Transaction.self,
                    SpendingCategory.self,
                    Budget.self,
                    BudgetReminder.self,
                    Goal.self,
                    AIUsageStats.self,
                    AIInsight.self,
                    SettingItem.self,
                    AIConversation.self,
                    AIMessage.self,
                    RecurringTransaction.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
                )
                logger.warning("CloudKit initialization failed, using local storage. Error: \(error.localizedDescription)")
            } catch {
                // ModelContainer initialization failed - app cannot function without database
                // This is a fatal condition that requires developer intervention
                fatalError("ModelContainer initialization failed: \(error.localizedDescription). The app cannot run without a valid data store.")
            }
        }
    }

    @MainActor
    func bootstrap() async {
        let context = container.mainContext
        do {
            if try context.fetch(FetchDescriptor<SpendingCategory>()).isEmpty {
                try context.saveInitialCategories()
            } else {
                // Migration: Convert SF Symbols to Emojis
                try context.migrateCategoriesToEmoji()
            }
            
            if try context.fetch(FetchDescriptor<SettingItem>()).isEmpty {
                context.insert(SettingItem(key: .onboardingCompleted, value: "false"))
            }
        } catch {
            logger.error("Bootstrap failed: \(error.localizedDescription)")
        }
    }
}

extension ModelContext {
    fileprivate func saveInitialCategories() throws {
        let defaults = SpendingCategory.defaultCategories
        defaults.forEach { insert($0) }
        try save()
    }
    
    fileprivate func migrateCategoriesToEmoji() throws {
        let categories = try fetch(FetchDescriptor<SpendingCategory>())
        var hasChanges = false
        
        let sfSymbolToEmoji: [String: String] = [
            "fork.knife": "🍔",
            "car.fill": "🚗",
            "bag.fill": "🛍️",
            "desktopcomputer": "💻",
            "film.fill": "🎬",
            "heart.text.square.fill": "🏥",
            "house.fill": "🏠",
            "graduationcap.fill": "🎓",
            "dollarsign.circle.fill": "💰",
            "chart.line.uptrend.xyaxis": "📈",
            "banknote.fill": "💵",
            "creditcard.fill": "💳",
            "cart.fill": "🛒",
            "gamecontroller.fill": "🎮",
            "tram.fill": "🚋",
            "airplane": "✈️",
            "cross.case.fill": "💼",
            "gift.fill": "🎁",
            "wifi": "🛜",
            "phone.fill": "📱"
        ]
        
        for category in categories {
            // If icon is already an emoji (short string), skip
            if category.icon.count <= 2 && !category.icon.contains(".") {
                continue
            }
            
            // Try to map from known SF Symbols
            if let emoji = sfSymbolToEmoji[category.icon] {
                category.icon = emoji
                hasChanges = true
            } else {
                // Fallback for unknown SF Symbols
                // Assign a default emoji based on type or just a generic one
                if category.type == .income {
                    category.icon = "💰"
                } else {
                    category.icon = "🏷️"
                }
                hasChanges = true
            }
        }
        
        if hasChanges {
            try save()
        }
    }
}
