import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]

    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showImportPicker = false
    @State private var importResult: ImportResult?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        Form {
            Section(header: Text("Data Management".localized)) {
                // Export Button
                Button(action: exportCSV) {
                    HStack {
                        if isExporting {
                            ProgressView()
                            Text("Exporting...".localized)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Transactions".localized)
                        }
                        Spacer()
                    }
                }
                .disabled(transactions.isEmpty || isExporting)

                // Import Button
                Button(action: { showImportPicker = true }) {
                    HStack {
                        if isImporting {
                            ProgressView()
                            Text("Importing...".localized)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Transactions".localized)
                        }
                        Spacer()
                    }
                }
                .disabled(isImporting)

                // Import Result
                if let result = importResult {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Import Completed".localized)
                                .foregroundColor(.green)
                        }
                        Text(String(format: NSLocalizedString("Successfully imported %d records, skipped %d duplicates", comment: ""), result.imported, result.skipped))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if transactions.isEmpty {
                    Text("No transaction data".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(String(format: NSLocalizedString("Total %d records", comment: ""), transactions.count))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Budget Management".localized)) {
                NavigationLink(destination: BudgetManagementView()) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        Text("Manage Budgets".localized)
                    }
                }

                Text("Set spending limits for categories or overall budget".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Category Management".localized)) {
                NavigationLink(destination: CategoryManagementView()) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        Text("Manage Categories".localized)
                    }
                }

                Text("Customize spending and income categories with emoji icons".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("定期交易".localized)) {
                NavigationLink(destination: RecurringTransactionsView()) {
                    HStack {
                        Image(systemName: "repeat.circle.fill")
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.6))
                        Text("定期交易")
                    }
                }

                Text("管理重复交易，如房租、订阅费等".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Data Settings".localized)
        .navigationBarTitleDisplayMode(.large)
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Error".localized, isPresented: Binding(
            get: { importError != nil },
            set: { _ in importError = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = importError {
                Text(error)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportCSV() {
        isExporting = true

        Task {
            do {
                let service = CSVService()
                let url = try service.export(transactions: transactions)

                await MainActor.run {
                    exportedFileURL = url
                    showShareSheet = true
                    isExporting = false

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        isImporting = true
        importResult = nil
        importError = nil

        Task {
            do {
                guard let url = try? result.get().first else {
                    await MainActor.run { isImporting = false }
                    return
                }

                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        isImporting = false
                        importError = "Could not access the selected file.".localized
                    }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let service = CSVService()
                let result = try service.import(url: url, context: context, strategy: .skipDuplicates)

                await MainActor.run {
                    importResult = result
                    isImporting = false

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DataSettingsView()
            .modelContainer(for: Transaction.self, inMemory: true)
    }
}
