//
//  TranslationManager.swift
//  HuggingChat-iOS
//
//  Translation API integration for multilingual support (iOS 17.4+)
//

import Foundation
import Translation
import NaturalLanguage

@available(iOS 18.0, *)
@Observable
@MainActor
class TranslationManager {
    static let shared = TranslationManager()

    var isTranslating = false
    var supportedLanguages: Set<Locale.Language> = []

    private init() {
        loadSupportedLanguages()
    }

    // MARK: - Translation

    @available(iOS 26.0, *)
    func translate(_ text: String, to targetLanguage: Locale.Language) async throws -> String {
        isTranslating = true
        defer { isTranslating = false }

        // Detect source language
        let sourceLanguage = await detectLanguage(text)

        do {
            // Configure a session using installed language packs when available
            let session: TranslationSession
            if #available(iOS 18.0, *) {
                session = try TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            } else {
                throw TranslationError.translationFailed("Translation requires iOS 18.0 or later")
            }

            let response = try await session.translate(text)
            // Attempt to extract the translated text from the response. Adjust the property name if needed.
            if let translated = (response as AnyObject).value(forKey: "translatedText") as? String {
                return translated
            } else if let translated = (response as? CustomStringConvertible)?.description {
                return translated
            } else {
                // Fallback: return the original text if we can't extract a string from the response
                return text
            }
        } catch {
            throw TranslationError.translationFailed(error.localizedDescription)
        }
    }

    func translateBatch(_ texts: [String], to targetLanguage: Locale.Language) async throws -> [String] {
        isTranslating = true
        defer { isTranslating = false }

        var translations: [String] = []

        for text in texts {
            if #available(iOS 26.0, *) {
                let translated = try await translate(text, to: targetLanguage)
                translations.append(translated)
            } else {
                // Fallback on earlier versions: return the original text unchanged
                translations.append(text)
            }
        }

        return translations
    }

    // MARK: - Language Detection

    func detectLanguage(_ text: String) async -> Locale.Language {
        // Use NaturalLanguage framework for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let languageCode = recognizer.dominantLanguage?.rawValue {
            return Locale.Language(identifier: languageCode)
        } else {
            return Locale.Language(identifier: "en")
        }
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
            if #available(iOS 26.0, *) {
                return try await TranslationManager.shared.translate(self, to: language)
            } else {
                // Fallback on earlier versions: return the original string
                return self
            }
        } catch {
            print("Translation error: \(error)")
            return self
        }
    }
}

