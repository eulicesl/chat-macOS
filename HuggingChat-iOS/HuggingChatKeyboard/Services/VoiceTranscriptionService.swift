//
//  VoiceTranscriptionService.swift
//  HuggingChatKeyboard
//
//  Voice transcription service using WhisperKit (on-device) or Speech Recognition API
//

import Foundation
import AVFoundation
import Speech

/// Service for transcribing voice input to text
@Observable
class VoiceTranscriptionService: NSObject {
    static let shared = VoiceTranscriptionService()

    // Audio engine and recognition
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    // State
    var isRecording: Bool = false
    var currentTranscription: String = ""
    var audioLevel: Float = 0.0

    // Callbacks
    var onTranscriptionUpdate: ((String) -> Void)?
    var onTranscriptionComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private override init() {
        super.init()
        setupAudioSession()
    }

    // MARK: - Permissions

    /// Requests microphone and speech recognition permissions
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let microphoneGranted = await AVAudioApplication.requestRecordPermission()

        guard microphoneGranted else {
            return false
        }

        // Request speech recognition permission
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Checks if permissions are granted
    func hasPermissions() -> Bool {
        let microphoneStatus = AVAudioApplication.shared.recordPermission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        return microphoneStatus == .granted && speechStatus == .authorized
    }

    // MARK: - Recording

    /// Starts voice recording and transcription
    func startRecording() throws {
        guard hasPermissions() else {
            throw TranscriptionError.permissionsNotGranted
        }

        guard !isRecording else { return }

        // Cancel any ongoing task
        stopRecording()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.unableToCreateRequest
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio session
        try setupAudioSession()

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on audio node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)

            // Calculate audio level for visualization
            self?.updateAudioLevel(from: buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcription = result.bestTranscription.formattedString
                self.currentTranscription = transcription
                self.onTranscriptionUpdate?(transcription)

                if result.isFinal {
                    self.onTranscriptionComplete?(transcription)
                    self.stopRecording()
                }
            }

            if let error = error {
                self.onError?(error)
                self.stopRecording()
            }
        }

        isRecording = true
    }

    /// Stops recording and completes transcription
    func stopRecording() {
        guard isRecording else { return }

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Finish recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isRecording = false

        // Notify completion with final transcription
        if !currentTranscription.isEmpty {
            onTranscriptionComplete?(currentTranscription)
        }

        currentTranscription = ""
    }

    // MARK: - Audio Setup

    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0

        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        audioLevel = average
    }

    // MARK: - Transcription from Audio File

    /// Transcribes an audio file
    func transcribeAudioFile(url: URL) async throws -> String {
        guard hasPermissions() else {
            throw TranscriptionError.permissionsNotGranted
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            speechRecognizer?.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    continuation.resume(returning: transcription)
                }
            }
        }
    }

    // MARK: - Utilities

    /// Returns available languages for speech recognition
    static func supportedLanguages() -> [Locale] {
        SFSpeechRecognizer.supportedLocales().sorted { locale1, locale2 in
            (locale1.localizedString(forIdentifier: locale1.identifier) ?? "") <
            (locale2.localizedString(forIdentifier: locale2.identifier) ?? "")
        }
    }

    /// Sets the language for speech recognition
    func setLanguage(_ locale: Locale) {
        // Note: Would need to recreate speechRecognizer with new locale
        // For now, this is a placeholder for language switching functionality
    }
}

// MARK: - Errors

enum TranscriptionError: Error, LocalizedError {
    case permissionsNotGranted
    case unableToCreateRequest
    case audioEngineError
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .permissionsNotGranted:
            return "Microphone and speech recognition permissions are required."
        case .unableToCreateRequest:
            return "Unable to create speech recognition request."
        case .audioEngineError:
            return "Audio engine error occurred."
        case .recognitionFailed:
            return "Speech recognition failed."
        }
    }
}

// MARK: - Alternative: WhisperKit Integration (Future Enhancement)

/// Alternative transcription using WhisperKit for fully on-device processing
/// This would require WhisperKit package and model files
///
/// Benefits:
/// - 100% offline transcription
/// - No cloud dependency
/// - Better privacy
/// - Support for more languages
///
/// Implementation outline:
/*
import WhisperKit

class WhisperKitTranscriptionService {
    private var whisperKit: WhisperKit?

    init() async {
        do {
            whisperKit = try await WhisperKit(model: "tiny.en")
        } catch {
            print("Failed to initialize WhisperKit: \(error)")
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionError.unableToCreateRequest
        }

        let result = try await whisperKit.transcribe(audioPath: audioURL.path)
        return result.text
    }
}
*/
