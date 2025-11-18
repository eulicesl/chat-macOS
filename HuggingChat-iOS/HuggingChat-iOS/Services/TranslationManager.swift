//
//  TranslationManager.swift
//  HuggingChat-iOS
//
//  Translation API integration for multilingual support (iOS 17.4+)
//

import Foundation
import Translation

@available(iOS 17.4, *)
@Observable
class TranslationManager {
    static let shared = TranslationManager()

    var isTranslating = false
    var supportedLanguages: Set<Locale.Language> = []

    private init() {
        loadSupportedLanguages()
    }

    // MARK: - Translation

    func translate(_ text: String, to targetLanguage: Locale.Language) async throws -> String {
        isTranslating = true
        defer { isTranslating = false }

        // Detect source language
        let sourceLanguage = await detectLanguage(text)

        let configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )

        let session = TranslationSession(configuration: configuration)

        do {
            let request = TranslationSession.Request(sourceText: text)
            let response = try await session.translate(request)
            return response.targetText
        } catch {
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }

    func translateBatch(_ texts: [String], to targetLanguage: Locale.Language) async throws -> [String] {
        isTranslating = true
        defer { isTranslating = false }

        var translations: [String] = []

        for text in texts {
            let translated = try await translate(text, to: targetLanguage)
            translations.append(translated)
        }

        return translations
    }

    // MARK: - Language Detection

    func detectLanguage(_ text: String) async -> Locale.Language {
        // Use NaturalLanguage framework for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let languageCode = recognizer.dominantLanguage?.rawValue,
              let language = Locale.Language(identifier: languageCode) else {
            return Locale.Language(identifier: "en")
        }

        return language
    }

    // MARK: - Supported Languages

    private func loadSupportedLanguages() {
        // Common languages supported by Translation API
        supportedLanguages = [
            Locale.Language(identifier: "en"),  // English
            Locale.Language(identifier: "es"),  // Spanish
            Locale.Language(identifier: "fr"),  // French
            Locale.Language(identifier: "de"),  // German
            Locale.Language(identifier: "it"),  // Italian
            Locale.Language(identifier: "pt"),  // Portuguese
            Locale.Language(identifier: "ru"),  // Russian
            Locale.Language(identifier: "zh"),  // Chinese
            Locale.Language(identifier: "ja"),  // Japanese
            Locale.Language(identifier: "ko"),  // Korean
            Locale.Language(identifier: "ar"),  // Arabic
            Locale.Language(identifier: "hi"),  // Hindi
        ]
    }

    func isLanguageSupported(_ language: Locale.Language) -> Bool {
        supportedLanguages.contains(language)
    }
}

// MARK: - Translation Error

enum TranslationError: Error, LocalizedError {
    case translationFailed(String)
    case unsupportedLanguage
    case invalidText

    var errorDescription: String? {
        switch self {
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .unsupportedLanguage:
            return "Language not supported"
        case .invalidText:
            return "Invalid text for translation"
        }
    }
}

// MARK: - Translation Extension

extension String {
    @available(iOS 17.4, *)
    func translated(to language: Locale.Language) async -> String {
        do {
            return try await TranslationManager.shared.translate(self, to: language)
        } catch {
            print("Translation error: \(error)")
            return self
        }
    }
}
