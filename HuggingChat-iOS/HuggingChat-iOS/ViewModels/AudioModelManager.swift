//
//  AudioModelManager.swift
//  HuggingChat-iOS
//

import Foundation
import AVFoundation
import Speech
import Observation
import WhisperKit

@MainActor
@Observable
class AudioModelManager: NSObject {
    var isRecording = false
    var isTranscribing = false
    var currentText = ""
    var errorMessage: String?
    var modelState: ModelState = .unloaded

    private var whisperKit: WhisperKit?
    private var audioRecorder: AVAudioRecorder?
    private var recordedFileURL: URL?

    enum ModelState: Equatable {
        case unloaded
        case loading
        case loaded
        case error(String)
    }

    override init() {
        super.init()
    }

    func loadModel() async {
        modelState = .loading

        do {
            // Load WhisperKit model
            whisperKit = try await WhisperKit()

            self.modelState = .loaded
        } catch {
            self.modelState = .error(error.localizedDescription)
            self.errorMessage = "Failed to load Whisper model: \(error.localizedDescription)"
        }
    }

    func startRecording() async throws {
        // Request microphone permission
        let recordingSession = AVAudioSession.sharedInstance()
        try recordingSession.setCategory(.playAndRecord, mode: .default)
        try recordingSession.setActive(true)

        // Setup audio recorder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordedFileURL = documentsPath.appendingPathComponent("recording.m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        if let url = recordedFileURL {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()

            self.isRecording = true
        }
    }

    func stopRecording() async {
        audioRecorder?.stop()

        self.isRecording = false

        // Start transcription
        if let url = recordedFileURL {
            await transcribe(audioURL: url)
        }
    }

    private func transcribe(audioURL: URL) async {
        guard let whisperKit = whisperKit else {
            self.errorMessage = "Whisper model not loaded"
            return
        }

        self.isTranscribing = true
        self.currentText = ""

        do {
            // Transcribe using WhisperKit
            let result = try await whisperKit.transcribe(audioPath: audioURL.path)

            self.currentText = result.first?.text ?? ""
            self.isTranscribing = false
        } catch {
            self.errorMessage = "Transcription failed: \(error.localizedDescription)"
            self.isTranscribing = false
        }
    }

    func reset() {
        currentText = ""
        errorMessage = nil
    }
}
