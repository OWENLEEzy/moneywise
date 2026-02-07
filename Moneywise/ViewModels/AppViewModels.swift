import Foundation
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: "owenlee.Moneywise", category: "AppViewModels")

@Observable final class GoalManager {
    private let context: ModelContext
    private var goalsDescriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\Goal.deadline)])

    private(set) var goals: [Goal] = []

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        do {
            goals = try context.fetch(goalsDescriptor)
        } catch {
            logger.error("Failed to fetch goals: \(error.localizedDescription)")
        }
    }

    func addGoal(_ goal: Goal) {
        context.insert(goal)
        context.saveSafe()
        reload()
    }

    func updateGoal(_ goal: Goal, mutate: (Goal) -> Void) {
        mutate(goal)
        context.saveSafe()
        reload()
    }

    func delete(_ goal: Goal) {
        context.delete(goal)
        context.saveSafe()
        reload()
    }
}

@Observable final class AIConfigurationStore {
    private let keychain = KeychainService()
    private let context: ModelContext

    var apiKey: String? {
        didSet {
            if let apiKey {
                keychain.set(apiKey, for: .geminiAPIKey)
            } else {
                keychain.delete(.geminiAPIKey)
            }
        }
    }

    private(set) var stats: AIUsageStats?
    var tutorialURL: URL? = URL(string: "https://ai.google.dev/gemini-api/docs")

    init(context: ModelContext) {
        self.context = context
        self.apiKey = keychain.value(for: .geminiAPIKey)
        if let existing = try? context.fetch(FetchDescriptor<AIUsageStats>()),
           let stats = existing.first {
            self.stats = stats
        } else {
            let stats = AIUsageStats()
            context.insert(stats)
            context.saveSafe()
            self.stats = stats
        }
    }

    func recordUsage(input: Int, output: Int) {
        let stats = stats ?? {
            let item = AIUsageStats()
            context.insert(item)
            return item
        }()
        stats.inputTokens += input
        stats.outputTokens += output
        stats.totalCalls += 1
        stats.date = .now
        context.saveSafe()
        self.stats = stats
    }

    func resetUsage() {
        stats?.inputTokens = 0
        stats?.outputTokens = 0
        stats?.totalCalls = 0
        stats?.date = .now
        context.saveSafe()
    }
}

