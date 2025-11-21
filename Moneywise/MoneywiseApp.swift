//
//  MoneywiseApp.swift
//  Moneywise
//
//  Created by Owen Lee Zhao Yi on 20/11/2025.
//

import SwiftUI
import SwiftData

@main
struct MoneywiseApp: App {
    @State private var persistenceController = PersistenceController.shared
    @State private var deeplinkRouter = DeeplinkRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, persistenceController.container.mainContext)
                .environment(\.managedGoals, GoalManager(context: persistenceController.container.mainContext))
                .environment(\.aiConfiguration, AIConfigurationStore(context: persistenceController.container.mainContext))
                .environment(\.deeplinkRouter, deeplinkRouter)
                .task {
                    await persistenceController.bootstrap()
                }
        }
        .modelContainer(persistenceController.container)
    }
}

// MARK: - Persistence

@Observable final class PersistenceController {
    static let shared = PersistenceController()
    let container: ModelContainer

    private init(inMemory: Bool = false) {
        do {
            container = try ModelContainer(
                for: Transaction.self,
                SpendingCategory.self,
                BudgetReminder.self,
                Goal.self,
                AIUsageStats.self,
                AIInsight.self,
                SettingItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Unresolved error \(error)")
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
            print("Bootstrap error: \(error)")
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
            print("Migrated categories to emojis")
        }
    }
}
