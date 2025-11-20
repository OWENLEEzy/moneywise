import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    @State private var searchText = ""
    @State private var filterType: TransactionType?
    
    var filteredTransactions: [Transaction] {
        allTransactions.filter { transaction in
            let matchesSearch = searchText.isEmpty || 
                transaction.note.localizedCaseInsensitiveContains(searchText) ||
                (transaction.category?.name.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesType = filterType == nil || transaction.type == filterType
            return matchesSearch && matchesType
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
                .onDelete(perform: deleteTransactions)
            }
            .searchable(text: $searchText, prompt: "Search transactions")
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { filterType = nil }) {
                            HStack {
                                Text("All")
                                if filterType == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button(action: { filterType = .expense }) {
                            HStack {
                                Text("Expense")
                                if filterType == .expense {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        Button(action: { filterType = .income }) {
                            HStack {
                                Text("Income")
                                if filterType == .income {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .overlay {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView {
                        Label("No transactions yet", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Transactions will appear here once you start tracking")
                    }
                }
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredTransactions[index])
        }
        try? context.save()
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category?.name ?? "Uncategorized")
                    .font(.headline)
                Text(transaction.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.coinFormatted)
                    .font(.headline)
                    .foregroundColor(transaction.type == .expense ? .red : .green)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
