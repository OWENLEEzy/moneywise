// CategoryManagementView.swift
import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SpendingCategory.name) private var categories: [SpendingCategory]
    @State private var showAddSheet = false
    @State private var categoryToEdit: SpendingCategory?
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        List {
            ForEach(categories) { category in
                HStack {
                    Text(category.icon)
                    Text(category.name)
                    Spacer()
                    Text(category.type == .income ? "Income".localized : "Expense".localized)
                        .font(.caption)
                        .padding(4)
                        .background(category.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteCategory(category)
                    } label: {
                        Label("Delete".localized, systemImage: "trash")
                    }
                    
                    Button {
                        categoryToEdit = category
                    } label: {
                        Label("Edit".localized, systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Categories".localized)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CategoryEditSheet(category: nil)
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryEditSheet(category: category)
        }
    }
    
    private func deleteCategory(_ category: SpendingCategory) {
        context.delete(category)
        context.saveSafe()
    }
}

struct CategoryEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var category: SpendingCategory?
    
    @State private var name: String = ""
    @State private var icon: String = "🏷️"
    @State private var type: TransactionType = .expense
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name".localized, text: $name)
                TextField("Icon (Emoji)".localized, text: $icon)
                Picker("Type".localized, selection: $type) {
                    Text("Expense".localized).tag(TransactionType.expense)
                    Text("Income".localized).tag(TransactionType.income)
                }
            }
            .navigationTitle(category == nil ? "New Category".localized : "Edit Category".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save".localized) { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let category = category {
                    name = category.name
                    icon = category.icon
                    type = category.type
                }
            }
        }
    }
    
    private func save() {
        if let category = category {
            category.name = name
            category.icon = icon
            category.type = type
        } else {
            let newCategory = SpendingCategory(name: name, icon: icon, colorHex: "#6B7280", type: type)
            context.insert(newCategory)
        }
        context.saveSafe()
        dismiss()
    }
}
