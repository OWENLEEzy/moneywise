import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]
    
    @State private var apiKey: String = ""
    @State private var savedApiKey: String?
    @State private var isTestingConnection: Bool = false
    @State private var testResult: TestResult?
    @State private var showAPIKey: Bool = false
    
    // CSV Import/Export
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showImportPicker = false
    @State private var importResult: ImportResult?
    @State private var isExporting = false
    @State private var isImporting = false
    
    // Notification settings
    @State private var dailyReminderEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    
    private let keychain = KeychainService()
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Gemini API Configuration")) {
                    // API Key Status
                    if let saved = savedApiKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key Saved")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                showAPIKey.toggle()
                            }) {
                                Image(systemName: showAPIKey ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        if showAPIKey {
                            Text(saved)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        } else {
                            Text("••••••••••••••••")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("API Key Not Configured")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // API Key Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter API Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Paste your Gemini API Key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    // Save Button
                    Button(action: saveAPIKey) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save API Key")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)
                    
                    // Test Connection Button
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Testing...")
                            } else {
                                Image(systemName: "network")
                                Text("Test Connection")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(savedApiKey == nil || isTestingConnection)
                    
                    // Test Result
                    if let result = testResult {
                        switch result {
                        case .success:
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("Connection Successful! API Key is valid")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        case .failure(let error):
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Connection Failed")
                                        .foregroundColor(.red)
                                }
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Help")) {
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Get Gemini API Key")
                                    .foregroundColor(.primary)
                                Text("Visit Google AI Studio")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructions")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("1. Visit the link above to get a free Gemini API Key")
                        Text("2. Copy the API Key and paste it into the input box")
                        Text("3. Click 'Save API Key'")
                        Text("4. Click 'Test Connection' to verify if the API Key is valid")
                        Text("5. You can now use the AI accounting features!")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("Data Management")) {
                    // Export Button
                    Button(action: exportCSV) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                Text("Exporting...")
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Transactions")
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
                                Text("Importing...")
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import Transactions")
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
                                Text("Import Completed")
                                    .foregroundColor(.green)
                            }
                            Text("Successfully imported \(result.imported) records, skipped \(result.skipped) duplicates")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if transactions.isEmpty {
                        Text("No transaction data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Total \(transactions.count) records")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("AI Model")
                        Spacer()
                        Text("Gemini 2.5 Flash")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSavedAPIKey()
                loadNotificationSettings()
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func loadSavedAPIKey() {
        savedApiKey = keychain.value(for: .geminiAPIKey)
    }
    
    private func saveAPIKey() {
        keychain.set(apiKey, for: .geminiAPIKey)
        savedApiKey = apiKey
        apiKey = ""
        testResult = nil
        
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func testConnection() {
        guard let key = savedApiKey else { return }
        
        isTestingConnection = true
        testResult = nil
        
        Task {
            do {
                let service = GeminiService()
                let testPrompt = GeminiPromptBuilder().transactionPrompt(with: "Test Connection")
                _ = try await service.send(payload: testPrompt, apiKey: key)
                
                await MainActor.run {
                    testResult = .success
                    isTestingConnection = false
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    testResult = .failure(error.localizedDescription)
                    isTestingConnection = false
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
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
        
        Task {
            do {
                guard let url = try? result.get().first else {
                    await MainActor.run { isImporting = false }
                    return
                }
                
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run { isImporting = false }
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
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
    
    private func loadAPIStats() -> AIUsageStats? {
        // Try to load from AIConfigurationStore
        let fetchDescriptor = FetchDescriptor<AIUsageStats>()
        return try? context.fetch(fetchDescriptor).first
    }
    
    // MARK: - Notification Methods
    
    private func loadNotificationSettings() {
        // Load from UserDefaults
        dailyReminderEnabled = UserDefaults.standard.bool(forKey: "dailyReminderEnabled")
        if let savedTime = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
            reminderTime = savedTime
        }
    }
    
    private func handleDailyReminderToggle(enabled: Bool) {
        Task {
            if enabled {
                // Request permission first
                let scheduler = NotificationScheduler()
                let granted = await scheduler.requestAuthorization()
                
                await MainActor.run {
                    if granted {
                        dailyReminderEnabled = true
                        UserDefaults.standard.set(true, forKey: "dailyReminderEnabled")
                        
                        // Schedule notification
                        Task {
                            let calendar = Calendar.current
                            let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
                            await NotificationScheduler().scheduleDailyReminder(
                                at: components,
                                body: "How was your day? Don't forget to log your expenses."
                            )
                        }
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        dailyReminderEnabled = false
                        UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                    }
                }
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: ["daily-log-21"]
                )
                UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private func handleReminderTimeChange(time: Date) {
        UserDefaults.standard.set(time, forKey: "reminderTime")
        if dailyReminderEnabled {
            Task {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.hour, .minute], from: time)
                await NotificationScheduler().scheduleDailyReminder(
                    at: components,
                    body: "How was your day? Don't forget to log your expenses."
                )
            }
        }
    }
}

// Helper view for sharing
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
