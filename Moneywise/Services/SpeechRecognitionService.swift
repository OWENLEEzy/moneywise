//
//  SpeechRecognitionService.swift
//  Moneywise
//
//  Created by Owen Lee on 2025-02-07.
//  Description: Speech-to-text service using Apple's SFSpeechRecognizer
//

import Foundation
import Speech
import AVFoundation
import Combine
import SwiftUI

/// # SpeechRecognitionService
///
/// ## Overview
/// Service responsible for converting speech to text using Apple's SFSpeechRecognizer.
/// Manages audio capture, recognition requests, and provides real-time transcription
/// results. Used primarily for voice-based transaction entry.
///
/// ## Usage
/// ```swift
/// @StateObject private var speechService = SpeechRecognitionService()
///
/// // Request permission first
/// let authorized = await speechService.requestAuthorization()
/// guard authorized else { return }
///
/// // Start recording
/// try await speechService.startRecording()
/// // User speaks...
/// let text = speechService.transcribedText
///
/// // Stop recording
/// speechService.stopRecording()
/// ```
///
/// ## Error Handling
/// - `SpeechError.recognizerUnavailable`: Speech recognizer not available on device
/// - `SpeechError.notAuthorized`: Microphone permission denied
/// - AVFoundation errors for audio session configuration
///
/// ## Thread Safety
/// This class is marked `@MainActor` and must be used on the main thread.
/// All `@Published` properties update on the main thread.
///
/// ## Dependencies
/// - Speech: SFSpeechRecognizer for speech recognition
/// - AVFoundation: AVAudioEngine for audio capture
/// - Combine: ObservableObject conformance for SwiftUI integration
///
/// ## Permissions
/// Requires:
/// - `NSMicrophoneUsageDescription` in Info.plist
/// - `NSSpeechRecognitionUsageDescription` in Info.plist
///
/// ## Platform Notes
/// - Requires iOS 13+ for SFSpeechRecognizer
/// - Recognition availability depends on device and locale
/// - Currently configured for en-US locale

/// Errors that can occur during speech recognition
enum SpeechError: Error, LocalizedError {
    case recognizerUnavailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "Speech recognition service unavailable"
        case .notAuthorized:
            return "Microphone permission required"
        }
    }
}

/// Service for speech-to-text conversion using SFSpeechRecognizer
@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Requests speech recognition and microphone permissions
    ///
    /// Must be called before starting recording. Presents system permission
    /// dialog on first request.
    ///
    /// - Returns: true if authorization granted, false otherwise
    /// - Note: Only shows permission dialog once; subsequent calls return cached result
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Starts recording and transcribing speech
    ///
    /// Configures audio session, creates recognition request, and begins
    /// listening for speech input. Results are streamed to `transcribedText`.
    ///
    /// - Throws: `SpeechError` if recognizer unavailable or audio session fails
    /// - Important: Call `stopRecording()` when done to release audio resources
    /// - Note: Partial results are updated in real-time via `transcribedText` publisher
    func startRecording() async throws {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true

        // Create audio engine
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        isRecording = true
        transcribedText = ""
        errorMessage = nil

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
    }

    /// Stops recording and releases audio resources
    ///
    /// Stops the audio engine, removes audio tap, and ends the recognition request.
    /// This method is safe to call multiple times and is automatically called
    /// when recognition completes or encounters an error.
    ///
    /// - Note: Always call this when done recording to properly release microphone
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }
}
