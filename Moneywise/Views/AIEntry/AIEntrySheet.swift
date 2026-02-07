// AIEntrySheet.swift
import SwiftUI
import Speech
import AVFoundation

struct AIEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let aiService: AIService

    @State private var isRecording = false
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    @State private var aiResponse: GeminiResponse?
    @State private var cancellationToken: CancellationToken? = nil
    
    // Speech recognizer components
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    ProgressView("Processing...")
                } else {
                    TextEditor(text: $recognizedText)
                        .frame(height: 150)
                        .border(Color.gray.opacity(0.5))
                }
                HStack {
                    Button(action: toggleRecording) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(isRecording ? .red : .blue)
                    }
                    .disabled(isProcessing)
                    
                    Button("Send".localized) {
                        Task { await processInput() }
                    }
                    .disabled(recognizedText.isEmpty || isProcessing)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("AI Entry".localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized) {
                        cancellationToken?.cancel()
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK".localized, role: .cancel) { }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showConfirmation) {
                if let response = aiResponse {
                    ConfirmationCard(response: response) { // onSave
                        Task { await saveTransaction(response) }
                    } onEdit: {
                        // Return to editing view with current text
                        showConfirmation = false
                    }
                }
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Request permissions
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            guard let self = self else { return }
            switch authStatus {
            case .authorized:
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    guard let self = self else { return }
                    if granted {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            self.beginAudioCapture()
                        }
                    } else {
                        self.errorMessage = "Microphone permission denied."
                    }
                }
            default:
                self.errorMessage = "Speech recognition permission denied."
            }
        }
    }
    
    private func beginAudioCapture() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognizer not available."
            return
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }
        }
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            errorMessage = "Audio engine couldn't start: \(error.localizedDescription)"
        }
        isRecording = true
    }
    
    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }
    
    private func processInput() async {
        guard !recognizedText.isEmpty else { return }
        isProcessing = true

        // Create a new cancellation token for this operation
        var token = CancellationToken()
        cancellationToken = token

        do {
            let response = try await aiService.parse(text: recognizedText, context: context, cancellationToken: &token)
            aiResponse = GeminiResponse(
                amount: Double(truncating: response.amount as NSNumber),
                type: response.type,
                category: response.category?.name,
                account: response.account,
                paymentMethod: response.paymentMethod,
                note: response.note,
                confidence: response.confidence,
                date: response.date
            )
            showConfirmation = true
        } catch {
            errorMessage = "AI processing failed: \(error.localizedDescription)"
        }
        isProcessing = false
        cancellationToken = nil
    }
    
    private func saveTransaction(_ response: GeminiResponse) async {
        do {
            try await aiService.saveTransaction(response, in: context)
            dismiss()
        } catch {
            errorMessage = "Saving transaction failed: \(error.localizedDescription)"
        }
    }
}


