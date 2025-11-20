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
            }
            if try context.fetch(FetchDescriptor<SettingItem>()).isEmpty {
                try context.insert(SettingItem(key: .onboardingCompleted, value: "false"))
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
}
