//
//  MultiLanguageService.swift
//  HuggingChatKeyboard
//
//  Multi-language support for keyboard
//  Provides localization and language-specific features
//

import Foundation
import Observation

/// Service for multi-language support in keyboard
@Observable
class MultiLanguageService {
    static let shared = MultiLanguageService()

    // Current language
    var currentLanguage: KeyboardLanguage = .english
    var secondaryLanguage: KeyboardLanguage? = nil
    var autoDetectLanguage: Bool = true

    // Localized commands
    private var localizedCommands: [String: [KeyboardLanguage: QuickCommand]] = [:]

    private init() {
        setupLocalizedCommands()
    }

    // MARK: - Language Management

    /// Sets the primary language
    func setLanguage(_ language: KeyboardLanguage) {
        currentLanguage = language
    }

    /// Sets a secondary language for bilingual support
    func setSecondaryLanguage(_ language: KeyboardLanguage?) {
        secondaryLanguage = language
    }

    /// Detects language from text
    func detectLanguage(from text: String) -> KeyboardLanguage {
        guard autoDetectLanguage else {
            return currentLanguage
        }

        // Use NaturalLanguage framework for detection
        if #available(iOS 16.0, *) {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)

            if let languageCode = recognizer.dominantLanguage?.rawValue {
                return KeyboardLanguage.fromCode(languageCode) ?? currentLanguage
            }
        }

        return currentLanguage
    }

    // MARK: - Localized Commands

    /// Gets commands for current language
    func getLocalizedCommands() -> [QuickCommand] {
        var commands: [QuickCommand] = []

        // Get commands for current language
        for (_, languageCommands) in localizedCommands {
            if let command = languageCommands[currentLanguage] {
                commands.append(command)
            }
        }

        return commands
    }

    /// Gets localized command trigger
    func getLocalizedTrigger(for commandId: String) -> String? {
        localizedCommands[commandId]?[currentLanguage]?.trigger
    }

    private func setupLocalizedCommands() {
        // AI Command - localized in 12 languages
        localizedCommands["ai"] = [
            .english: QuickCommand(trigger: "/ai", prompt: "Answer: {input}", icon: "sparkles"),
            .spanish: QuickCommand(trigger: "/ia", prompt: "Responder: {input}", icon: "sparkles"),
            .french: QuickCommand(trigger: "/ia", prompt: "Répondre: {input}", icon: "sparkles"),
            .german: QuickCommand(trigger: "/ki", prompt: "Antworten: {input}", icon: "sparkles"),
            .italian: QuickCommand(trigger: "/ia", prompt: "Rispondere: {input}", icon: "sparkles"),
            .portuguese: QuickCommand(trigger: "/ia", prompt: "Responder: {input}", icon: "sparkles"),
            .dutch: QuickCommand(trigger: "/ai", prompt: "Antwoorden: {input}", icon: "sparkles"),
            .polish: QuickCommand(trigger: "/ai", prompt: "Odpowiedz: {input}", icon: "sparkles"),
            .russian: QuickCommand(trigger: "/ии", prompt: "Ответить: {input}", icon: "sparkles"),
            .chinese: QuickCommand(trigger: "/ai", prompt: "回答：{input}", icon: "sparkles"),
            .japanese: QuickCommand(trigger: "/ai", prompt: "回答：{input}", icon: "sparkles"),
            .korean: QuickCommand(trigger: "/ai", prompt: "답변: {input}", icon: "sparkles")
        ]

        // Translate Command
        localizedCommands["translate"] = [
            .english: QuickCommand(trigger: "/translate", prompt: "Translate to English: {input}", icon: "globe"),
            .spanish: QuickCommand(trigger: "/traducir", prompt: "Traducir al español: {input}", icon: "globe"),
            .french: QuickCommand(trigger: "/traduire", prompt: "Traduire en français: {input}", icon: "globe"),
            .german: QuickCommand(trigger: "/übersetzen", prompt: "Übersetzen auf Deutsch: {input}", icon: "globe"),
            .italian: QuickCommand(trigger: "/tradurre", prompt: "Tradurre in italiano: {input}", icon: "globe"),
            .portuguese: QuickCommand(trigger: "/traduzir", prompt: "Traduzir para português: {input}", icon: "globe"),
            .dutch: QuickCommand(trigger: "/vertalen", prompt: "Vertalen naar Nederlands: {input}", icon: "globe"),
            .polish: QuickCommand(trigger: "/tłumaczyć", prompt: "Przetłumaczyć na polski: {input}", icon: "globe"),
            .russian: QuickCommand(trigger: "/перевести", prompt: "Перевести на русский: {input}", icon: "globe"),
            .chinese: QuickCommand(trigger: "/翻译", prompt: "翻译成中文：{input}", icon: "globe"),
            .japanese: QuickCommand(trigger: "/翻訳", prompt: "日本語に翻訳：{input}", icon: "globe"),
            .korean: QuickCommand(trigger: "/번역", prompt: "한국어로 번역: {input}", icon: "globe")
        ]

        // Improve Command
        localizedCommands["improve"] = [
            .english: QuickCommand(trigger: "/improve", prompt: "Improve: {input}", icon: "wand.and.stars"),
            .spanish: QuickCommand(trigger: "/mejorar", prompt: "Mejorar: {input}", icon: "wand.and.stars"),
            .french: QuickCommand(trigger: "/améliorer", prompt: "Améliorer: {input}", icon: "wand.and.stars"),
            .german: QuickCommand(trigger: "/verbessern", prompt: "Verbessern: {input}", icon: "wand.and.stars"),
            .italian: QuickCommand(trigger: "/migliorare", prompt: "Migliorare: {input}", icon: "wand.and.stars"),
            .portuguese: QuickCommand(trigger: "/melhorar", prompt: "Melhorar: {input}", icon: "wand.and.stars"),
            .dutch: QuickCommand(trigger: "/verbeteren", prompt: "Verbeteren: {input}", icon: "wand.and.stars"),
            .polish: QuickCommand(trigger: "/poprawić", prompt: "Poprawić: {input}", icon: "wand.and.stars"),
            .russian: QuickCommand(trigger: "/улучшить", prompt: "Улучшить: {input}", icon: "wand.and.stars"),
            .chinese: QuickCommand(trigger: "/改进", prompt: "改进：{input}", icon: "wand.and.stars"),
            .japanese: QuickCommand(trigger: "/改善", prompt: "改善：{input}", icon: "wand.and.stars"),
            .korean: QuickCommand(trigger: "/개선", prompt: "개선: {input}", icon: "wand.and.stars")
        ]
    }

    // MARK: - Localization Helpers

    /// Gets localized string for key
    func localizedString(_ key: String) -> String {
        // In production, use NSLocalizedString or String catalogs
        LocalizationStrings.get(key, language: currentLanguage)
    }

    /// Gets localized placeholder
    func getPlaceholder(for mode: KeyboardMode) -> String {
        switch mode {
        case .ai:
            return localizedString("placeholder.ai")
        case .voice:
            return localizedString("placeholder.voice")
        case .commands:
            return localizedString("placeholder.commands")
        default:
            return localizedString("placeholder.standard")
        }
    }
}

// MARK: - Keyboard Language

enum KeyboardLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case hindi = "hi"
    case turkish = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .russian: return "Русский"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .turkish: return "Türkçe"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .dutch: return "🇳🇱"
        case .polish: return "🇵🇱"
        case .russian: return "🇷🇺"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .turkish: return "🇹🇷"
        }
    }

    static func fromCode(_ code: String) -> KeyboardLanguage? {
        allCases.first { $0.rawValue == code }
    }
}

// MARK: - Localization Strings

struct LocalizationStrings {
    static func get(_ key: String, language: KeyboardLanguage) -> String {
        let strings: [String: [KeyboardLanguage: String]] = [
            "placeholder.ai": [
                .english: "Ask AI anything...",
                .spanish: "Pregunta cualquier cosa...",
                .french: "Demandez n'importe quoi...",
                .german: "Fragen Sie irgendetwas...",
                .italian: "Chiedi qualsiasi cosa...",
                .portuguese: "Pergunte qualquer coisa...",
                .dutch: "Vraag wat dan ook...",
                .polish: "Zapytaj o cokolwiek...",
                .russian: "Спросите что угодно...",
                .chinese: "问任何问题...",
                .japanese: "何でも聞いてください...",
                .korean: "무엇이든 물어보세요..."
            ],
            "placeholder.voice": [
                .english: "Tap to start recording",
                .spanish: "Toca para grabar",
                .french: "Appuyez pour enregistrer",
                .german: "Tippen zum Aufnehmen",
                .italian: "Tocca per registrare",
                .portuguese: "Toque para gravar",
                .dutch: "Tik om op te nemen",
                .polish: "Dotknij, aby nagrać",
                .russian: "Нажмите для записи",
                .chinese: "点击开始录音",
                .japanese: "録音を開始するにはタップ",
                .korean: "녹음을 시작하려면 탭하세요"
            ],
            "button.send": [
                .english: "Send",
                .spanish: "Enviar",
                .french: "Envoyer",
                .german: "Senden",
                .italian: "Invia",
                .portuguese: "Enviar",
                .dutch: "Verzenden",
                .polish: "Wyślij",
                .russian: "Отправить",
                .chinese: "发送",
                .japanese: "送信",
                .korean: "보내기"
            ]
        ]

        return strings[key]?[language] ?? key
    }
}

enum KeyboardMode {
    case standard
    case ai
    case voice
    case commands
}

import NaturalLanguage
