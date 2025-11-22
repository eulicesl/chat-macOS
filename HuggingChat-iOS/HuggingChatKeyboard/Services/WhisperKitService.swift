//
//  WhisperKitService.swift
//  HuggingChatKeyboard
//
//  Offline voice transcription using WhisperKit
//  Provides 100% on-device speech-to-text without network dependency
//

import Foundation
import AVFoundation
import Observation

// Note: In production, import WhisperKit
// import WhisperKit

/// Service for offline voice transcription using WhisperKit
/// Provides fully on-device speech-to-text with no network required
@Observable
class WhisperKitService {
    static let shared = WhisperKitService()

    // WhisperKit instance (placeholder until package is added)
    // private var whisperKit: WhisperKit?
    private var isInitialized: Bool = false

    // Audio recording
    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    // State
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var currentTranscription: String = ""
    var selectedModel: String = "whisper-base"
    var selectedLanguage: String = "en"
    var audioLevel: Float = 0.0

    // Callbacks
    var onTranscriptionUpdate: ((String) -> Void)?
    var onTranscriptionComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private let modelManager = OfflineModelManager.shared

    private init() {
        Task {
            await initializeWhisperKit()
        }
    }

    // MARK: - Initialization

    private func initializeWhisperKit() async {
        // Check if model is installed
        guard modelManager.isModelInstalled(selectedModel) else {
            print("WhisperKit model not installed: \(selectedModel)")
            return
        }

        guard let modelPath = modelManager.getModelPath(selectedModel) else {
            print("WhisperKit model path not found")
            return
        }

        do {
            // In production with WhisperKit package:
            // whisperKit = try await WhisperKit(modelPath: modelPath.path)
            // isInitialized = true

            // Placeholder initialization
            isInitialized = true
            print("WhisperKit initialized with model: \(selectedModel)")
        } catch {
            print("Failed to initialize WhisperKit: \(error)")
            onError?(error)
        }
    }

    // MARK: - Model Management

    /// Sets the Whisper model to use
    func setModel(_ modelId: String) async {
        guard modelManager.isModelInstalled(modelId) else {
            onError?(WhisperError.modelNotInstalled)
            return
        }

        selectedModel = modelId
        isInitialized = false
        await initializeWhisperKit()
    }

    /// Sets the language for transcription
    func setLanguage(_ language: String) {
        selectedLanguage = language
    }

    /// Checks if WhisperKit is ready
    func isReady() -> Bool {
        isInitialized && modelManager.isModelInstalled(selectedModel)
    }

    // MARK: - Permissions

    /// Requests microphone permission
    func requestPermissions() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    /// Starts recording audio for transcription
    func startRecording() throws {
        guard isReady() else {
            throw WhisperError.notInitialized
        }

        guard !isRecording else {
            throw WhisperError.alreadyRecording
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)

        // Create temporary audio file
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("whisper_recording_\(UUID().uuidString).wav")

        guard let recordingURL = recordingURL else {
            throw WhisperError.recordingFailed
        }

        // Configure audio file
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        audioFile = try AVAudioFile(
            forWriting: recordingURL,
            settings: recordingFormat.settings
        )

        // Install tap to record audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, let audioFile = self.audioFile else { return }

            do {
                try audioFile.write(from: buffer)
                self.updateAudioLevel(from: buffer)
            } catch {
                print("Failed to write audio buffer: \(error)")
            }
        }

        // Start audio engine
        try audioEngine.start()
        isRecording = true
    }

    /// Stops recording and transcribes
    func stopRecording() {
        guard isRecording else { return }

        // Stop audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        isRecording = false

        // Transcribe the recorded audio
        guard let recordingURL = recordingURL else {
            return
        }

        Task {
            await transcribeAudioFile(url: recordingURL)
        }
    }

    // MARK: - Transcription

    /// Transcribes an audio file
    private func transcribeAudioFile(url: URL) async {
        guard isReady() else {
            onError?(WhisperError.notInitialized)
            return
        }

        await MainActor.run {
            isTranscribing = true
        }

        defer {
            Task { @MainActor in
                isTranscribing = false
            }

            // Clean up temporary file
            try? FileManager.default.removeItem(at: url)
        }

        do {
            // In production with WhisperKit:
            /*
            let result = try await whisperKit?.transcribe(
                audioPath: url.path,
                language: selectedLanguage
            )

            let transcription = result?.text ?? ""
            */

            // Placeholder transcription (simulated)
            let transcription = await simulateTranscription(url: url)

            await MainActor.run {
                currentTranscription = transcription
                onTranscriptionComplete?(transcription)
            }
        } catch {
            await MainActor.run {
                onError?(error)
            }
        }
    }

    /// Transcribes audio with streaming updates (future enhancement)
    func transcribeWithStreaming(url: URL) async throws -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                // In production, WhisperKit could provide streaming transcription
                // For now, return final result

                guard isReady() else {
                    continuation.finish()
                    return
                }

                let transcription = await simulateTranscription(url: url)
                continuation.yield(transcription)
                continuation.finish()
            }
        }
    }

    // MARK: - Utilities

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

    /// Simulates transcription (placeholder until WhisperKit is integrated)
    private func simulateTranscription(url: URL) async -> String {
        // Simulate processing time
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        // Return placeholder transcription
        return "This is a simulated transcription. In production, WhisperKit would process the audio file at \(url.lastPathComponent) and return the actual transcription using the \(selectedModel) model."
    }

    // MARK: - Supported Languages

    static func supportedLanguages() -> [TranscriptionLanguage] {
        [
            TranscriptionLanguage(code: "en", name: "English"),
            TranscriptionLanguage(code: "es", name: "Spanish"),
            TranscriptionLanguage(code: "fr", name: "French"),
            TranscriptionLanguage(code: "de", name: "German"),
            TranscriptionLanguage(code: "it", name: "Italian"),
            TranscriptionLanguage(code: "pt", name: "Portuguese"),
            TranscriptionLanguage(code: "nl", name: "Dutch"),
            TranscriptionLanguage(code: "pl", name: "Polish"),
            TranscriptionLanguage(code: "ru", name: "Russian"),
            TranscriptionLanguage(code: "zh", name: "Chinese"),
            TranscriptionLanguage(code: "ja", name: "Japanese"),
            TranscriptionLanguage(code: "ko", name: "Korean"),
            TranscriptionLanguage(code: "ar", name: "Arabic"),
            TranscriptionLanguage(code: "hi", name: "Hindi"),
            TranscriptionLanguage(code: "tr", name: "Turkish")
        ]
    }
}

// MARK: - Supporting Types

struct TranscriptionLanguage: Identifiable, Codable {
    let code: String
    let name: String

    var id: String { code }
}

enum WhisperError: Error, LocalizedError {
    case notInitialized
    case modelNotInstalled
    case alreadyRecording
    case recordingFailed
    case transcriptionFailed
    case audioFileNotFound

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "WhisperKit is not initialized. Please download a model first."
        case .modelNotInstalled:
            return "Whisper model is not installed. Download it from settings."
        case .alreadyRecording:
            return "Already recording"
        case .recordingFailed:
            return "Failed to start recording"
        case .transcriptionFailed:
            return "Transcription failed"
        case .audioFileNotFound:
            return "Audio file not found"
        }
    }
}

// MARK: - Integration Notes
/*
 To fully integrate WhisperKit:

 1. Add WhisperKit package to project:
    https://github.com/argmaxinc/WhisperKit

 2. Add to Package Dependencies in Xcode:
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.0.0")

 3. Import WhisperKit at top of file:
    import WhisperKit

 4. Uncomment whisperKit initialization code

 5. Download models using OfflineModelManager

 6. Models should be in correct format for WhisperKit

 Benefits of WhisperKit:
 - 100% offline transcription
 - No network required
 - Better privacy
 - Faster than cloud API in many cases
 - Supports 90+ languages with appropriate models
 - On-device processing on Neural Engine
 - Lower latency
 */
