import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "owenlee.Moneywise", category: "ModelContext")

extension ModelContext {
    func category(named name: String?, type: TransactionType) throws -> SpendingCategory? {
        guard let name, !name.isEmpty else { return nil }
        let descriptor = FetchDescriptor<SpendingCategory>()
        if let match = try fetch(descriptor).first(where: { $0.name == name }) {
            return match
        }
        let category = SpendingCategory(name: name, icon: "❓", colorHex: "#94A3B8", type: type)
        insert(category)
        return category
    }

    func usageStatsRecord() throws -> AIUsageStats {
        if let stats = try fetch(FetchDescriptor<AIUsageStats>()).first {
            return stats
        }
        let stats = AIUsageStats()
        insert(stats)
        saveSafe()
        return stats
    }

    /// Safely saves the context, logging any errors instead of crashing.
    /// - Returns: `true` if save succeeded, `false` otherwise.
    @discardableResult
    func saveSafe() -> Bool {
        do {
            try save()
            return true
        } catch {
            logger.error("ModelContext save failed: \(error.localizedDescription)")
            return false
        }
    }
}

