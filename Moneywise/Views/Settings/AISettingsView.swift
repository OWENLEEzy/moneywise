import SwiftUI
import SwiftData

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey: String = ""
    @State private var savedApiKey: String?
    @AppStorage("customBaseURL") private var customBaseURL: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var testResult: TestResult?
    @State private var showAPIKey: Bool = false

    private let keychain = KeychainService()

    enum TestResult {
        case success
        case failure(String)
    }

    var body: some View {
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
                if let apiKeyURL = URL(string: "https://aistudio.google.com/app/apikey") {
                    Link(destination: apiKeyURL) {
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
        }
        .navigationTitle("AI Settings".localized)
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

                guard let testURL = URL(string: "\(cleanBaseURL)/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)") else {
                    await MainActor.run {
                        testResult = .failure("Invalid URL configuration")
                        isTestingConnection = false
                    }
                    return
                }

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
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
