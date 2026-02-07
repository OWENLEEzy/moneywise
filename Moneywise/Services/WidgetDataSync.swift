// WidgetDataSync.swift
import Foundation
import SwiftData

/// 服务类：负责将 App 数据同步到 Widget
/// 使用 App Groups 共享数据
final class WidgetDataSync {
    static let shared = WidgetDataSync()

    private let suiteName = "group.owenlee.Moneywise"
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    /// 更新 Widget 数据
    /// - Parameters:
    ///   - monthlySpending: 本月支出
    ///   - monthlyBudget: 本月预算
    ///   - activeGoalsCount: 活跃目标数量
    func updateWidgetData(
        monthlySpending: Decimal,
        monthlyBudget: Decimal,
        activeGoalsCount: Int
    ) {
        guard let defaults = sharedDefaults else { return }

        defaults.set((monthlySpending as NSDecimalNumber).doubleValue, forKey: "monthlySpending")
        defaults.set((monthlyBudget as NSDecimalNumber).doubleValue, forKey: "monthlyBudget")
        defaults.set(activeGoalsCount, forKey: "activeGoalsCount")
        defaults.set(Date(), forKey: "lastUpdate")

        // 通知 Widget 刷新
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 从交易数据计算并更新 Widget
    func syncFromTransactions(
        _ transactions: [Transaction],
        budget: Decimal,
        goalsCount: Int
    ) {
        let calendar = Calendar.current
        let now = Date()

        // 计算本月支出
        let monthComponent = calendar.dateComponents([.year, .month], from: now)
        guard let startOfMonth = calendar.date(from: monthComponent),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        let monthlyTransactions = transactions.filter {
            $0.date >= startOfMonth && $0.date <= endOfMonth && $0.type == .expense
        }

        // 排除存到目标的金额
        let monthlySpending = monthlyTransactions.filter {
            !($0.note.contains("Goal funding:") || $0.category?.name == "Savings")
        }.reduce(0) { $0 + $1.amount }

        updateWidgetData(
            monthlySpending: monthlySpending,
            monthlyBudget: budget,
            activeGoalsCount: goalsCount
        )
    }
}
