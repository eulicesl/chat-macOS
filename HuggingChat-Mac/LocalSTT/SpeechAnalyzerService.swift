//
//  SpeechAnalyzerService.swift
//  HuggingChat-Mac
//
//  High-quality offline transcription using Apple's SpeechAnalyzer
//

import Foundation
import Speech
import AVFoundation
import Observation

/// Transcription result from SpeechAnalyzer
struct SpeechAnalyzerResult {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isFinal: Bool
}

/// Service for managing on-device speech transcription using Apple's SpeechAnalyzer
@Observable class SpeechAnalyzerService {

    // MARK: - Public Properties
    var isRecording: Bool = false
    var isTranscribing: Bool = false
    var currentText: String = ""
    var confirmedText: String = ""
    var hypothesisText: String = ""
    var bufferEnergy: [Float] = []
    var bufferSeconds: Double = 0
    var isTranscriptionComplete: Bool = false
    var availableLanguages: [String] = []

    // MARK: - Private Properties
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var resultsTask: Task<Void, Never>?
    private var audioLevelTimer: Timer?
    private let locale: Locale
    private var audioSamples: [Float] = []

    // Constants
    private let sampleRate: Double = 16000.0

    // MARK: - Initialization

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
        setupAvailableLanguages()
    }

    deinit {
        cleanup()
    }

    // MARK: - Public Methods

    /// Prepare the speech recognition model for a specific language
    /// This downloads the model if needed and should be called before startRecording
    static func prepare(languageCode: String) async throws {
        // Check if SpeechAnalyzer is available (iOS 18+, macOS 15+)
        guard #available(macOS 15.0, iOS 18.0, *) else {
            throw SpeechAnalyzerError.notSupported
        }

        // Prepare the language model
        try await SFSpeechRecognizer.prepareOnDeviceRecognition(
            forLocale: Locale(identifier: languageCode)
        )
    }

    /// Start recording and transcribing audio
    func startRecording() async throws {
        guard !isRecording else { return }

        // Request microphone permission
        guard await requestMicrophonePermission() else {
            throw SpeechAnalyzerError.microphonePermissionDenied
        }

        // Check if we can use SpeechAnalyzer
        if #available(macOS 15.0, iOS 18.0, *) {
            try await startSpeechAnalyzerTranscription()
        } else {
            // Fallback to SFSpeechRecognizer on older systems
            try await startLegacyTranscription()
        }
    }

    /// Stop recording and finalize transcription
    func stopRecording() async {
        guard isRecording else { return }

        isRecording = false

        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Stop audio level monitoring
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        // Finalize the analyzer
        if #available(macOS 15.0, iOS 18.0, *) {
            analyzer?.endAudio()
        }

        // Wait for final results
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Cancel results task
        resultsTask?.cancel()
        resultsTask = nil

        // Finalize text
        finalizeText()

        isTranscribing = false
        isTranscriptionComplete = true
    }

    /// Reset the service state
    func resetState() {
        cleanup()
        currentText = ""
        confirmedText = ""
        hypothesisText = ""
        bufferEnergy = []
        bufferSeconds = 0
        isTranscriptionComplete = false
        audioSamples = []
    }

    /// Get the complete transcription
    func getFullTranscript() -> String {
        finalizeText()
        return confirmedText
    }

    // MARK: - Private Methods (SpeechAnalyzer - macOS 15+)

    @available(macOS 15.0, iOS 18.0, *)
    private func startSpeechAnalyzerTranscription() async throws {
        // Create analyzer and transcriber
        analyzer = SpeechAnalyzer()
        transcriber = SpeechTranscriber(locale: locale)

        guard let analyzer = analyzer, let transcriber = transcriber else {
            throw SpeechAnalyzerError.initializationFailed
        }

        // Add transcriber to analyzer
        do {
            try await analyzer.addModule(transcriber)
        } catch {
            // If SpeechTranscriber fails, try DictationTranscriber as fallback
            print("SpeechTranscriber not available, trying DictationTranscriber")
            let dictationTranscriber = DictationTranscriber(locale: locale)
            try await analyzer.addModule(dictationTranscriber)
            self.transcriber = dictationTranscriber as? SpeechTranscriber
        }

        // Setup audio engine
        try setupAudioEngine { [weak self] buffer in
            guard let self = self else { return }

            // Send audio to analyzer
            Task {
                try? await self.analyzer?.appendAudioBuffer(buffer)
            }

            // Update energy levels for visualization
            Task { @MainActor in
                self.updateAudioLevels(from: buffer)
            }
        }

        // Start processing results
        resultsTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                for try await result in transcriber.results {
                    await self.handleTranscriptionResult(result)
                }
            } catch {
                print("Error processing transcription results: \(error)")
            }
        }

        isRecording = true
        isTranscribing = true
    }

    // MARK: - Private Methods (Legacy SFSpeechRecognizer)

    private func startLegacyTranscription() async throws {
        let recognizer = SFSpeechRecognizer(locale: locale)

        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw SpeechAnalyzerError.recognizerNotAvailable
        }

        // Check for on-device recognition
        guard recognizer.supportsOnDeviceRecognition else {
            throw SpeechAnalyzerError.onDeviceNotSupported
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true

        // Setup audio engine
        try setupAudioEngine { [weak self] buffer in
            request.append(buffer)

            Task { @MainActor in
                self?.updateAudioLevels(from: buffer)
            }
        }

        // Start recognition
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    if result.isFinal {
                        self.confirmedText = result.bestTranscription.formattedString
                        self.hypothesisText = ""
                    } else {
                        self.hypothesisText = result.bestTranscription.formattedString
                    }
                    self.currentText = self.confirmedText + self.hypothesisText
                }

                if let error = error {
                    print("Recognition error: \(error)")
                }
            }
        }

        isRecording = true
        isTranscribing = true
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine(audioCallback: @escaping (AVAudioPCMBuffer) -> Void) throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap to receive audio data
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            audioCallback(buffer)
        }

        // Prepare and start the engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Result Handling

    @available(macOS 15.0, iOS 18.0, *)
    private func handleTranscriptionResult(_ result: SpeechTranscriber.Result) async {
        await MainActor.run {
            // Update confirmed text with finalized segments
            if !result.text.isEmpty {
                // Check if this is a new confirmed segment
                if result.isFinal {
                    // Append to confirmed text
                    if !confirmedText.isEmpty && !confirmedText.hasSuffix(" ") {
                        confirmedText += " "
                    }
                    confirmedText += result.text
                    hypothesisText = ""
                } else {
                    // Update hypothesis
                    hypothesisText = result.text
                }

                // Update current text
                currentText = confirmedText + (hypothesisText.isEmpty ? "" : " " + hypothesisText)
            }
        }
    }

    // MARK: - Audio Level Monitoring

    private func updateAudioLevels(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map { channelDataValue[$0] }

        // Calculate RMS (Root Mean Square) for audio level
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))

        // Convert to energy level (0-1)
        let energy = min(max(rms * 10, 0), 1)

        // Update buffer energy (keep last 6 values for visualization)
        bufferEnergy.append(energy)
        if bufferEnergy.count > 6 {
            bufferEnergy.removeFirst()
        }

        // Update buffer seconds
        audioSamples.append(contentsOf: channelDataValueArray)
        bufferSeconds = Double(audioSamples.count) / sampleRate
    }

    // MARK: - Helper Methods

    private func requestMicrophonePermission() async -> Bool {
        #if os(macOS)
        return await AVCaptureDevice.requestAccess(for: .audio)
        #else
        return await AVAudioSession.sharedInstance().requestRecordPermission()
        #endif
    }

    private func finalizeText() {
        if !hypothesisText.isEmpty {
            if !confirmedText.isEmpty && !confirmedText.hasSuffix(" ") {
                confirmedText += " "
            }
            confirmedText += hypothesisText
            hypothesisText = ""
        }
        currentText = confirmedText
    }

    private func cleanup() {
        resultsTask?.cancel()
        resultsTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        audioLevelTimer?.invalidate()
        audioLevelTimer = nil

        if #available(macOS 15.0, iOS 18.0, *) {
            analyzer?.endAudio()
        }

        analyzer = nil
        transcriber = nil
    }

    private func setupAvailableLanguages() {
        // Get available locales for speech recognition
        let recognizer = SFSpeechRecognizer()
        availableLanguages = SFSpeechRecognizer.supportedLocales()
            .map { $0.identifier }
            .sorted()
    }
}

// MARK: - Extensions for macOS 15 Compatibility

@available(macOS 15.0, iOS 18.0, *)
extension SpeechTranscriber.Result {
    var isFinal: Bool {
        // Results from SpeechTranscriber are considered final
        return true
    }
}

// MARK: - Error Types

enum SpeechAnalyzerError: LocalizedError {
    case notSupported
    case microphonePermissionDenied
    case initializationFailed
    case recognizerNotAvailable
    case onDeviceNotSupported

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "SpeechAnalyzer requires macOS 15.0 or later"
        case .microphonePermissionDenied:
            return "Microphone permission was denied"
        case .initializationFailed:
            return "Failed to initialize SpeechAnalyzer"
        case .recognizerNotAvailable:
            return "Speech recognizer is not available"
        case .onDeviceNotSupported:
            return "On-device recognition is not supported"
        }
    }
}
