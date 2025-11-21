import SwiftUI
import SwiftData

struct CategoryEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var categoryToEdit: SpendingCategory?
    
    @State private var name: String = ""
    @State private var icon: String = "🍔"
    @State private var color: Color = .blue
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
    
    private let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .gray, .black,
        Color(red: 0.2, green: 0.8, blue: 0.6) // Theme color
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
                        ForEach(presetColors, id: \.self) { presetColor in
                            Circle()
                                .fill(presetColor)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: color == presetColor ? 2 : 0)
                                )
                                .onTapGesture {
                                    color = presetColor
                                }
                        }
                    }
                    .padding(.vertical)
                    
                    ColorPicker("Custom Color", selection: $color)
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
                    color = Color(hex: category.colorHex) ?? .blue
                    type = category.type
                }
            }
        }
    }
    
    private func saveCategory() {
        let colorHex = color.toHex() ?? "#000000"
        
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
