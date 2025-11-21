import SwiftUI
import SwiftData

struct CategoryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var categoryToEdit: SpendingCategory?
    
    @State private var name: String = ""
    @State private var icon: String = "🍔"
    @State private var colorHex: String = "#3B82F6" // Default blue
    @State private var type: TransactionType = .expense
    
    private let commonEmojis = [
        // Food & Drink
        "🍔", "🍕", "🍜", "☕", "🍺",
        // Transport
        "🚗", "🚌", "🚇", "✈️", "🚲",
        // Shopping
        "🛍️", "👕", "📱", "💄", "🎁",
        // Entertainment
        "🎬", "🎮", "🎵", "📚", "⚽",
        // Healthcare
        "🏥", "💊", "🩺", "💉",
        // Money
        "💰", "💵", "💳", "🏦",
        // Other
        "🏠", "💻", "📧", "🎓", "🐕"
    ]
    
    private let presetColorPairs: [(color: Color, hex: String)] = [
        (.red, "#EF4444"),
        (.orange, "#F97316"),
        (.yellow, "#F59E0B"),
        (.green, "#10B981"),
        (.blue, "#3B82F6"),
        (.purple, "#8B5CF6"),
        (.pink, "#EC4899"),
        (.gray, "#6B7280"),
        (Color(red: 0.2, green: 0.8, blue: 0.6), "#34D399") // Theme color
    ]
    
    init(categoryToEdit: SpendingCategory? = nil) {
        self.categoryToEdit = categoryToEdit
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { type in
                            Text(type.localizedTitle).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                        ForEach(commonEmojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .padding(8)
                                .background(icon == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    icon = emoji
                                }
                        }
                    }
                    .padding(.vertical)
                }
                
                Section(header: Text("Color")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
                        ForEach(presetColorPairs, id: \.hex) { pair in
                            Circle()
                                .fill(pair.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == pair.hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    colorHex = pair.hex
                                }
                        }
                    }
                    .padding(.vertical)
                    

                }
            }
            .navigationTitle(categoryToEdit == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let category = categoryToEdit {
                    name = category.name
                    icon = category.icon
                    colorHex = category.colorHex
                    type = category.type
                }
            }
        }
    }
    
    private func saveCategory() {
        
        if let category = categoryToEdit {
            category.name = name
            category.icon = icon
            category.colorHex = colorHex
            category.type = type
        } else {
            let newCategory = SpendingCategory(name: name, icon: icon, colorHex: colorHex, type: type)
            context.insert(newCategory)
        }
    }
}
