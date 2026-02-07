// MoneywiseWidget.swift
import WidgetKit
import SwiftUI

// MARK: - Widget Entry

struct MoneywiseEntry: TimelineEntry {
    let date: Date
    let monthlySpending: Decimal
    let monthlyBudget: Decimal
    let budgetPercentage: Double
    let activeGoalsCount: Int
    let isOverBudget: Bool
}

struct MoneywiseWidget: Widget {
    let kind: String = "MoneywiseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoneywiseProvider()) { entry in
            MoneywiseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Moneywise")
        .description("Track your spending and budget at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Provider

struct MoneywiseProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoneywiseEntry {
        MoneywiseEntry(
            date: Date(),
            monthlySpending: 1250.50,
            monthlyBudget: 2000,
            budgetPercentage: 0.625,
            activeGoalsCount: 3,
            isOverBudget: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MoneywiseEntry) -> Void) {
        let entry = MoneywiseEntry(
            date: Date(),
            monthlySpending: 1250.50,
            monthlyBudget: 2000,
            budgetPercentage: 0.625,
            activeGoalsCount: 3,
            isOverBudget: false
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // Get data from UserDefaults (app and widget share data via App Groups)
        let sharedDefaults = UserDefaults(suiteName: "group.owenlee.Moneywise")

        let monthlySpending = Decimal(doubleValue: sharedDefaults?.double(forKey: "monthlySpending") ?? 0.0)
        let monthlyBudget = Decimal(doubleValue: sharedDefaults?.double(forKey: "monthlyBudget") ?? 2000.0)
        let activeGoalsCount = sharedDefaults?.integer(forKey: "activeGoalsCount") ?? 0

        let budgetPercentage: Double
        if monthlyBudget > 0 {
            budgetPercentage = min((monthlySpending as NSDecimalNumber).doubleValue / (monthlyBudget as NSDecimalNumber).doubleValue, 1.0)
        } else {
            budgetPercentage = 0
        }

        let isOverBudget = monthlySpending > monthlyBudget

        let entry = MoneywiseEntry(
            date: Date(),
            monthlySpending: monthlySpending,
            monthlyBudget: monthlyBudget,
            budgetPercentage: budgetPercentage,
            activeGoalsCount: activeGoalsCount,
            isOverBudget: isOverBudget
        )

        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

struct MoneywiseWidgetEntryView: View {
    var entry: MoneywiseProvider.Entry

    var body: some View {
        if #available(iOS 17.0, *) {
            WidgetView(entry: entry)
        } else {
            FallbackWidgetView(entry: entry)
        }
    }
}

@available(iOS 17.0, *)
struct WidgetView: View {
    var entry: MoneywiseProvider.Entry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// Small Widget - Shows spending overview
struct SmallWidgetView: View {
    var entry: MoneywiseProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.white)
                Text("Moneywise")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.monthlySpending.coinFormatted)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("spent this month")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.isOverBudget ? .red : .white)
                            .frame(width: geometry.size.width * entry.budgetPercentage, height: 4)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text("\(Int(entry.budgetPercentage * 100))% of budget")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.8, blue: 0.6),
                    Color(red: 0.1, green: 0.6, blue: 0.5)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// Medium Widget - Shows more details
struct MediumWidgetView: View {
    var entry: MoneywiseProvider.Entry

    var body: some View {
        HStack(spacing: 0) {
            // Left side - Spending
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.white)
                    Text("Moneywise")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.monthlySpending.coinFormatted)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("spent this month")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.white.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(entry.isOverBudget ? .red : .white)
                                .frame(width: geometry.size.width * entry.budgetPercentage, height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("\(Int(entry.budgetPercentage * 100))% of budget")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.2, green: 0.8, blue: 0.6),
                        Color(red: 0.1, green: 0.6, blue: 0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Right side - Budget & Goals
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "chart.bar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Budget")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(entry.monthlyBudget.coinFormatted)
                        .font(.system(size: 16, weight: .semibold))
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Active Goals")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(entry.activeGoalsCount)")
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                if entry.isOverBudget {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Over budget!")
                            .font(.caption2)
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }
}

// Fallback for iOS 16
struct FallbackWidgetView: View {
    var entry: MoneywiseProvider.Entry

    var body: some View {
        SmallWidgetView(entry: entry)
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    MoneywiseWidget()
} timeline: {
    MoneywiseEntry(
        date: .now,
        monthlySpending: 1250.50,
        monthlyBudget: 2000,
        budgetPercentage: 0.625,
        activeGoalsCount: 3,
        isOverBudget: false
    )
}

#Preview(as: .systemMedium) {
    MoneywiseWidget()
} timeline: {
    MoneywiseEntry(
        date: .now,
        monthlySpending: 1250.50,
        monthlyBudget: 2000,
        budgetPercentage: 0.625,
        activeGoalsCount: 3,
        isOverBudget: false
    )
}
