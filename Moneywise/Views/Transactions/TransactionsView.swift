import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    
    @State private var searchText = ""
    @State private var selectedType: TransactionType? = nil
    @State private var transactionToEdit: Transaction?
    @State private var toastMessage: String?
    
    var filteredTransactions: [Transaction] {
        var result = allTransactions
        
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }
        
        if !searchText.isEmpty {
            result = result.filter { transaction in
                let noteMatch = transaction.note.localizedCaseInsensitiveContains(searchText)
                let categoryMatch = transaction.category?.name.localizedCaseInsensitiveContains(searchText) == true
                return noteMatch || categoryMatch
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTransactions) { transaction in
                    Button {
                        transactionToEdit = transaction
                    } label: {
                        TransactionRow(transaction: transaction)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            context.delete(transaction)
                        } label: {
                            Label("Delete".localized, systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            transactionToEdit = transaction
                        } label: {
                            Label("Edit".localized, systemImage: "pencil")
                        }
                        .tint(Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                }
                .onDelete(perform: deleteTransactions) // Keep existing onDelete for consistency or remove if swipeActions fully replace it
            }
            .navigationTitle("Transactions".localized)
            .searchable(text: $searchText, prompt: "Search transactions".localized)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            selectedType = nil
                        } label: {
                            Label("All".localized, systemImage: "tray.full")
                        }
                        
                        Button {
                            selectedType = .expense
                        } label: {
                            Label("Expense".localized, systemImage: "arrow.down.right")
                        }
                        
                        Button {
                            selectedType = .income
                        } label: {
                            Label("Income".localized, systemImage: "arrow.up.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedType == nil ? .primary : Color(red: 0.2, green: 0.8, blue: 0.6))
                    }
                }
            }
            .sheet(item: $transactionToEdit) { transaction in
                ManualEntrySheet(toastMessage: $toastMessage, transactionToEdit: transaction)
            }
            .overlay(alignment: .top) {
                if let message = toastMessage {
                    ToastView(message: message) {
                        toastMessage = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 40)
                }
            }
            .overlay {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView {
                        Label("No transactions yet".localized, systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Transactions will appear here once you start tracking".localized)
                    }
                }
            }
        }
    }
    
    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredTransactions[index])
        }
        context.saveSafe()
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            if let category = transaction.category {
                Text(category.icon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            } else {
                Text("❓")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if let categoryName = transaction.category?.name {
                    Text(categoryName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                if let note = transaction.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.amount.coinFormatted)
                    .font(.headline)
                    .foregroundColor(transaction.type == .expense ? .red : .green) // Keep consistent with Home view colors
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
