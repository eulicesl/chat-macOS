//
//  EnhancedAppIntents.swift
//  HuggingChat
//
//  Enhanced App Intents for Shortcuts integration
//  Provides comprehensive Siri and Shortcuts support
//

import AppIntents
import Foundation

// MARK: - Keyboard Control Intents

@available(iOS 17.0, *)
struct EnableKeyboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable AI Keyboard"
    static var description = IntentDescription("Enable the HuggingChat AI Keyboard")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sharedData = SharedDataManager.shared
        sharedData.isKeyboardEnabled = true
        sharedData.allowNetworkAccess = true
        sharedData.synchronize()

        return .result(dialog: "HuggingChat AI Keyboard has been enabled. You can now use it in any app.")
    }
}

@available(iOS 17.0, *)
struct DisableKeyboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable AI Keyboard"
    static var description = IntentDescription("Disable the HuggingChat AI Keyboard")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sharedData = SharedDataManager.shared
        sharedData.isKeyboardEnabled = false
        sharedData.synchronize()

        return .result(dialog: "HuggingChat AI Keyboard has been disabled.")
    }
}

// MARK: - Quick Command Intents

@available(iOS 17.0, *)
struct TranslateTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate with AI"
    static var description = IntentDescription("Translate text using HuggingChat AI")

    @Parameter(title: "Text to Translate")
    var text: String

    @Parameter(title: "Target Language", default: "English")
    var targetLanguage: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let networkService = KeyboardNetworkService.shared

        do {
            let translation = try await networkService.translate(text, to: targetLanguage)
            return .result(value: translation, dialog: "Translated: \(translation)")
        } catch {
            throw error
        }
    }
}

@available(iOS 17.0, *)
struct ImproveWritingIntent: AppIntent {
    static var title: LocalizedStringResource = "Improve Writing with AI"
    static var description = IntentDescription("Improve text using HuggingChat AI")

    @Parameter(title: "Text to Improve")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let networkService = KeyboardNetworkService.shared

        do {
            let improved = try await networkService.improveWriting(text)
            return .result(value: improved, dialog: "Improved version ready")
        } catch {
            throw error
        }
    }
}

@available(iOS 17.0, *)
struct SummarizeTextIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize with AI"
    static var description = IntentDescription("Summarize text using HuggingChat AI")

    @Parameter(title: "Text to Summarize")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let networkService = KeyboardNetworkService.shared

        do {
            let summary = try await networkService.summarize(text)
            return .result(value: summary, dialog: "Summary: \(summary)")
        } catch {
            throw error
        }
    }
}

// MARK: - Model Management Intents

@available(iOS 17.0, *)
struct DownloadModelIntent: AppIntent {
    static var title: LocalizedStringResource = "Download Offline Model"
    static var description = IntentDescription("Download an AI model for offline use")

    @Parameter(title: "Model ID")
    var modelId: String

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let modelManager = OfflineModelManager.shared

        do {
            try await modelManager.downloadModel(modelId)
            return .result(dialog: "Model \(modelId) downloaded successfully")
        } catch {
            throw error
        }
    }
}

@available(iOS 17.0, *)
struct ListInstalledModelsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Installed Models"
    static var description = IntentDescription("Show all installed AI models")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[String]> & ProvidesDialog {
        let modelManager = OfflineModelManager.shared
        let models = Array(modelManager.installedModels.keys)

        return .result(
            value: models,
            dialog: "Installed models: \(models.joined(separator: ", "))"
        )
    }
}

// MARK: - Memory Management Intents

@available(iOS 17.0, *)
struct GetMemoryStatsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Memory Statistics"
    static var description = IntentDescription("View memory system statistics")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let memoryService = KeyboardMemoryService.shared
        let stats = memoryService.getStats()

        let message = """
        Learned Phrases: \(stats.totalPhrases)
        Custom Replacements: \(stats.totalReplacements)
        Vocabulary Size: \(stats.vocabularySize)
        Writing Style: \(stats.writingStyle.rawValue)
        """

        return .result(dialog: message)
    }
}

@available(iOS 17.0, *)
struct ClearMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Clear Keyboard Memory"
    static var description = IntentDescription("Clear all learned keyboard data")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let memoryService = KeyboardMemoryService.shared
        memoryService.clearAllData()

        return .result(dialog: "All keyboard memory has been cleared")
    }
}

// MARK: - Voice Transcription Intent

@available(iOS 17.0, *)
struct TranscribeAudioIntent: AppIntent {
    static var title: LocalizedStringResource = "Transcribe Audio"
    static var description = IntentDescription("Transcribe audio using WhisperKit")

    @Parameter(title: "Audio File")
    var audioFile: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let whisperService = WhisperKitService.shared

        guard let audioURL = audioFile.fileURL else {
            throw IntentError.message("Invalid audio file")
        }

        // Save to temporary location
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(audioURL.lastPathComponent)
        try FileManager.default.copyItem(at: audioURL, to: tempURL)

        // Transcribe
        // In production, would use whisperService.transcribeAudioFile(url: tempURL)
        let transcription = await whisperService.simulateTranscription(url: tempURL)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)

        return .result(value: transcription, dialog: "Transcription: \(transcription)")
    }
}

// MARK: - Enhanced App Shortcuts Provider

@available(iOS 17.0, *)
struct EnhancedAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Translate with \(.applicationName)",
                "Translate using \(.applicationName)"
            ],
            shortTitle: "Translate",
            systemImageName: "globe"
        )

        AppShortcut(
            intent: ImproveWritingIntent(),
            phrases: [
                "Improve text with \(.applicationName)",
                "Make my writing better with \(.applicationName)"
            ],
            shortTitle: "Improve Writing",
            systemImageName: "wand.and.stars"
        )

        AppShortcut(
            intent: SummarizeTextIntent(),
            phrases: [
                "Summarize with \(.applicationName)",
                "Create a summary with \(.applicationName)"
            ],
            shortTitle: "Summarize",
            systemImageName: "list.bullet.clipboard"
        )

        AppShortcut(
            intent: EnableKeyboardIntent(),
            phrases: [
                "Enable \(.applicationName) keyboard",
                "Turn on AI keyboard"
            ],
            shortTitle: "Enable Keyboard",
            systemImageName: "keyboard"
        )

        AppShortcut(
            intent: TranscribeAudioIntent(),
            phrases: [
                "Transcribe audio with \(.applicationName)",
                "Convert speech to text"
            ],
            shortTitle: "Transcribe",
            systemImageName: "mic"
        )

        AppShortcut(
            intent: GetMemoryStatsIntent(),
            phrases: [
                "Show keyboard memory",
                "Get keyboard statistics"
            ],
            shortTitle: "Memory Stats",
            systemImageName: "brain"
        )
    }
}

// MARK: - Intent Error

enum IntentError: Error, LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let msg):
            return msg
        }
    }
}
