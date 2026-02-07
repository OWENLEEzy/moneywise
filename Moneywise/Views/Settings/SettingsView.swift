import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]

    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var savedApiKey: String?

    private let keychain = KeychainService()

    var body: some View {
        NavigationStack {
            Form {
                // AI Settings Section
                Section {
                    NavigationLink(destination: AISettingsView()) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("AI Settings".localized)
                                if let saved = savedApiKey {
                                    Text("API Key Configured".localized)
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("API Key Not Set".localized)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }

                // Data Settings Section
                Section {
                    NavigationLink(destination: DataSettingsView()) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("Data Settings".localized)
                                Text("Import/Export, Budgets, Categories".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // General Settings Section
                Section {
                    NavigationLink(destination: GeneralSettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.gray)
                            VStack(alignment: .leading) {
                                Text("General Settings".localized)
                                Text("Theme, Language, Notifications".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Quick Stats Section
                Section(header: Text("Quick Stats".localized)) {
                    HStack {
                        Text("Total Transactions".localized)
                        Spacer()
                        Text("\(transactions.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Language".localized)
                        Spacer()
                        Text(languageManager.selectedLanguage.displayName)
                            .foregroundColor(.secondary)
                    }
                }

                // About Section
                Section(header: Text("About".localized)) {
                    HStack {
                        Text("AI Model".localized)
                        Spacer()
                        Text("Gemini 2.5 Flash")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version".localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSavedAPIKey()
            }
        }
    }

    private func loadSavedAPIKey() {
        savedApiKey = keychain.value(for: .geminiAPIKey)
    }
}

// Helper view for sharing (kept for DataSettingsView)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
