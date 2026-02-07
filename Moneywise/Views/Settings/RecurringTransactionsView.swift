import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.recurringManager) private var manager
    @State private var showingAddSheet = false

    var body: some View {
        List {
            if manager?.active.isEmpty ?? true {
                ContentUnavailableView {
                    Label("无定期交易", systemImage: "repeat")
                } description: {
                    Text("点击 + 添加定期交易，如房租、订阅等")
                } actions: {
                    Button("添加定期交易") {
                        showingAddSheet = true
                    }
                }
            } else {
                ForEach(manager?.active ?? []) { recurring in
                    RecurringTransactionCard(recurring: recurring)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                manager?.delete(recurring)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                manager?.toggleActive(recurring)
                            } label: {
                                Label("暂停", systemImage: "pause.circle")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle("定期交易")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddRecurringTransactionSheet()
        }
    }
}

struct RecurringTransactionCard: View {
    let recurring: RecurringTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Text(recurring.categoryIcon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(recurring.type == .expense ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(recurring.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(recurring.frequency.localizedName) · ¥\(String(format: "%.2f", (recurring.amount as NSDecimalNumber).doubleValue))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if recurring.daysUntilDue == 0 {
                    Text("今天到期")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .cornerRadius(8)
                } else if recurring.isDueSoon {
                    Text("\(recurring.daysUntilDue) 天后到期")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("下次: \(recurring.nextDueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsView()
    }
}
