import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]
    
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @State private var apiKey: String = ""
    @State private var savedApiKey: String?
    @AppStorage("customBaseURL") private var customBaseURL: String = ""
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
    
    @State private var weeklyGoalEnabled = false
    @State private var weeklyGoalDay: Int = 2 // Monday
    @State private var weeklyGoalTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    
    private let keychain = KeychainService()
    
    enum TestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Gemini API Configuration".localized)) {
                    // API Key Status
                    if let saved = savedApiKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API Key Saved".localized)
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
                            Text("API Key Not Configured".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // API Key Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter API Key".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        SecureField("Paste your Gemini API Key".localized, text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    
                    // Custom Base URL Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom API URL (Optional)".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("https://generativelanguage.googleapis.com", text: $customBaseURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        
                        Text("Useful for proxies or custom gateways".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Save Button
                    Button(action: saveAPIKey) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save Configuration".localized)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty && savedApiKey == nil)
                    
                    // Test Connection Button
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Testing...".localized)
                            } else {
                                Image(systemName: "network")
                                Text("Test Connection".localized)
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
                                Text("Connection Successful! API Key is valid".localized)
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        case .failure(let error):
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Connection Failed".localized)
                                        .foregroundColor(.red)
                                }
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Help".localized)) {
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Get Gemini API Key".localized)
                                    .foregroundColor(.primary)
                                Text("Visit Google AI Studio".localized)
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
                        Text("Instructions".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("1. Visit the link above to get a free Gemini API Key".localized)
                        Text("2. Copy the API Key and paste it into the input box".localized)
                        Text("3. Click 'Save API Key'".localized)
                        Text("4. Click 'Test Connection' to verify if the API Key is valid".localized)
                        Text("5. You can now use the AI accounting features!".localized)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
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
                
                Section(header: Text("Notifications".localized)) {
                    // Daily Reminder
                    Toggle(isOn: Binding(
                        get: { dailyReminderEnabled },
                        set: { handleDailyReminderToggle(enabled: $0) }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Daily Log Reminder".localized)
                            Text("Get reminded to log your expenses".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if dailyReminderEnabled {
                        DatePicker("Reminder Time".localized, selection: Binding(
                            get: { reminderTime },
                            set: { handleReminderTimeChange(time: $0) }
                        ), displayedComponents: .hourAndMinute)
                    }
                    
                    // Weekly Goal Progress
                    Toggle(isOn: Binding(
                        get: { weeklyGoalEnabled },
                        set: { handleWeeklyGoalToggle(enabled: $0) }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Weekly Goal Progress".localized)
                            Text("Track your savings progress".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if weeklyGoalEnabled {
                        Picker("Day of Week".localized, selection: Binding(
                            get: { weeklyGoalDay },
                            set: { 
                                weeklyGoalDay = $0
                                handleWeeklySettingsChange()
                            }
                        )) {
                            Text("Monday".localized).tag(2)
                            Text("Tuesday".localized).tag(3)
                            Text("Wednesday".localized).tag(4)
                            Text("Thursday".localized).tag(5)
                            Text("Friday".localized).tag(6)
                            Text("Saturday".localized).tag(7)
                            Text("Sunday".localized).tag(1)
                        }
                        
                        DatePicker("Time".localized, selection: Binding(
                            get: { weeklyGoalTime },
                            set: { 
                                weeklyGoalTime = $0
                                handleWeeklySettingsChange()
                            }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                Section(header: Text("Language".localized)) {
                    Picker("Language".localized, selection: $languageManager.selectedLanguageCode) {
                        ForEach(Language.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
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
                loadNotificationSettings()
            }
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
    }
    
    private func loadSavedAPIKey() {
        savedApiKey = keychain.value(for: .geminiAPIKey)
    }
    
    private func saveAPIKey() {
        if !apiKey.isEmpty {
            keychain.set(apiKey, for: .geminiAPIKey)
            savedApiKey = apiKey
            apiKey = ""
        }
        // customBaseURL is saved automatically via @AppStorage
        
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
                // Construct URL based on custom setting
                let baseURLString = customBaseURL.isEmpty ? "https://generativelanguage.googleapis.com" : customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove trailing slash if present
                let cleanBaseURL = baseURLString.hasSuffix("/") ? String(baseURLString.dropLast()) : baseURLString
                
                let testURL = URL(string: "\(cleanBaseURL)/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!
                
                print("🌐 [Connection Test] Testing URL: \(testURL.absoluteString)")
                var request = URLRequest(url: testURL)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Simple payload to test generation
                let payload = ["contents": [["parts": [["text": "Hello"]]]]]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                request.timeoutInterval = 10
                
                // Configure Proxy
                let config = URLSessionConfiguration.default
                config.connectionProxyDictionary = [
                    "HTTPEnable": 1,
                    "HTTPProxy": "127.0.0.1",
                    "HTTPPort": 50960,
                    "HTTPSEnable": 1,
                    "HTTPSProxy": "127.0.0.1",
                    "HTTPSPort": 50960
                ]
                let session = URLSession(configuration: config)
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "InvalidResponse", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
                }
                
                await MainActor.run {
                    if (200...299).contains(httpResponse.statusCode) {
                        testResult = .success
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        // Try to parse Google error
                        var errorMessage = "Connection Failed (Code: \(httpResponse.statusCode))"
                        
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let errorObj = json["error"] as? [String: Any],
                           let message = errorObj["message"] as? String {
                            errorMessage = message
                        } else if let text = String(data: data, encoding: .utf8) {
                            errorMessage = text
                        }
                        
                        testResult = .failure(errorMessage)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                    }
                    isTestingConnection = false
                }
            } catch let error as URLError {
                await MainActor.run {
                    switch error.code {
                    case .notConnectedToInternet:
                        testResult = .failure("No Internet Connection")
                    case .timedOut:
                        testResult = .failure("Request Timed Out")
                    case .cannotFindHost, .cannotConnectToHost:
                        testResult = .failure("Host Unreachable")
                    default:
                        testResult = .failure("Network Error: \(error.localizedDescription)")
                    }
                    isTestingConnection = false
                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
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
    
    @State private var importError: String?

    // ... (existing code)

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
        
        weeklyGoalEnabled = UserDefaults.standard.bool(forKey: "weeklyGoalEnabled")
        weeklyGoalDay = UserDefaults.standard.integer(forKey: "weeklyGoalDay")
        if weeklyGoalDay == 0 { weeklyGoalDay = 2 } // Default to Monday
        if let savedGoalTime = UserDefaults.standard.object(forKey: "weeklyGoalTime") as? Date {
            weeklyGoalTime = savedGoalTime
        }
    }
    
    private func handleDailyReminderToggle(enabled: Bool) {
        Task {
            if enabled {
                let scheduler = NotificationScheduler()
                let granted = await scheduler.requestAuthorization()
                
                await MainActor.run {
                    if granted {
                        dailyReminderEnabled = true
                        UserDefaults.standard.set(true, forKey: "dailyReminderEnabled")
                        scheduleDaily()
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        dailyReminderEnabled = false
                        UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                    }
                }
            } else {
                NotificationScheduler().cancelDailyReminder()
                UserDefaults.standard.set(false, forKey: "dailyReminderEnabled")
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private func handleWeeklyGoalToggle(enabled: Bool) {
        Task {
            if enabled {
                let scheduler = NotificationScheduler()
                let granted = await scheduler.requestAuthorization()
                
                await MainActor.run {
                    if granted {
                        weeklyGoalEnabled = true
                        UserDefaults.standard.set(true, forKey: "weeklyGoalEnabled")
                        scheduleWeekly()
                        
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } else {
                        weeklyGoalEnabled = false
                        UserDefaults.standard.set(false, forKey: "weeklyGoalEnabled")
                    }
                }
            } else {
                NotificationScheduler().cancelWeeklyGoalReminder()
                UserDefaults.standard.set(false, forKey: "weeklyGoalEnabled")
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private func scheduleDaily() {
        Task {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
            await NotificationScheduler().scheduleDailyReminder(
                at: components,
                body: "How was your day? Don't forget to log your expenses."
            )
        }
    }
    
    private func scheduleWeekly() {
        Task {
            // Fetch goals to calculate progress
            // Note: In a real app, we might want to fetch this fresh or pass it in.
            // For now, we can't easily access the @Query goals from here in a static context,
            // so we'll rely on the fact that the NotificationService calculates it or we pass it.
            // Wait, NotificationService needs the goals passed in.
            // We need to fetch goals here using the context.
            
            let descriptor = FetchDescriptor<Goal>()
            if let goals = try? context.fetch(descriptor) {
                await NotificationScheduler().scheduleWeeklyGoalReminder(
                    dayOfWeek: weeklyGoalDay,
                    time: weeklyGoalTime,
                    goals: goals
                )
            }
        }
    }
    
    private func handleReminderTimeChange(time: Date) {
        UserDefaults.standard.set(time, forKey: "reminderTime")
        if dailyReminderEnabled {
            scheduleDaily()
        }
    }
    
    private func handleWeeklySettingsChange() {
        UserDefaults.standard.set(weeklyGoalDay, forKey: "weeklyGoalDay")
        UserDefaults.standard.set(weeklyGoalTime, forKey: "weeklyGoalTime")
        if weeklyGoalEnabled {
            scheduleWeekly()
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
