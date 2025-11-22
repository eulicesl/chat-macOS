//
//  KeyboardMemoryService.swift
//  HuggingChat-iOS
//
//  Memory service specifically for keyboard operations
//

import Foundation

// MARK: - Writing Style

enum WritingStyle: String, Codable {
    case casual = "Casual"
    case professional = "Professional"
    case academic = "Academic"
    case creative = "Creative"
}

// MARK: - Keyboard Statistics

struct KeyboardStats {
    let totalPhrases: Int
    let totalReplacements: Int
    let vocabularySize: Int
    let writingStyle: WritingStyle
}

// MARK: - Keyboard Memory Service

@Observable
final class KeyboardMemoryService: @unchecked Sendable {
    static let shared = KeyboardMemoryService()

    private let sharedData = SharedDataManager.shared
    private let memoryManager = MemoryManager.shared

    private var learnedPhrases: [String: Int] = [:]
    private var customReplacements: [String: String] = [:]
    var writingStyle: WritingStyle = .casual

    private init() {
        loadData()
    }

    // MARK: - Data Management

    private func loadData() {
        // Load from UserDefaults
        if let phrasesData = UserDefaults.standard.data(forKey: "keyboard_learned_phrases"),
           let phrases = try? JSONDecoder().decode([String: Int].self, from: phrasesData) {
            learnedPhrases = phrases
        }

        if let replacementsData = UserDefaults.standard.data(forKey: "keyboard_replacements"),
           let replacements = try? JSONDecoder().decode([String: String].self, from: replacementsData) {
            customReplacements = replacements
        }

        if let styleRaw = UserDefaults.standard.string(forKey: "keyboard_writing_style"),
           let style = WritingStyle(rawValue: styleRaw) {
            writingStyle = style
        }
    }

    private func saveData() {
        if let phrasesData = try? JSONEncoder().encode(learnedPhrases) {
            UserDefaults.standard.set(phrasesData, forKey: "keyboard_learned_phrases")
        }

        if let replacementsData = try? JSONEncoder().encode(customReplacements) {
            UserDefaults.standard.set(replacementsData, forKey: "keyboard_replacements")
        }

        UserDefaults.standard.set(writingStyle.rawValue, forKey: "keyboard_writing_style")
    }

    // MARK: - Learning

    func learnPhrase(_ phrase: String) {
        let normalized = phrase.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return }

        learnedPhrases[normalized] = (learnedPhrases[normalized] ?? 0) + 1
        saveData()

        // Also store in memory system for long-term learning
        memoryManager.storeUserPattern(
            pattern: normalized,
            frequency: learnedPhrases[normalized] ?? 1,
            importance: 0.5
        )
    }

    func addReplacement(trigger: String, replacement: String) {
        customReplacements[trigger] = replacement
        saveData()
    }

    func removeReplacement(trigger: String) {
        customReplacements.removeValue(forKey: trigger)
        saveData()
    }

    func setWritingStyle(_ style: WritingStyle) {
        writingStyle = style
        saveData()

        memoryManager.storeUserPreference(
            key: "writing_style",
            value: style.rawValue,
            importance: 0.8
        )
    }

    // MARK: - Suggestions

    func getSuggestions(for prefix: String) -> [String] {
        let normalizedPrefix = prefix.lowercased()

        return learnedPhrases
            .filter { $0.key.hasPrefix(normalizedPrefix) }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }
    }

    func getReplacement(for trigger: String) -> String? {
        return customReplacements[trigger]
    }

    // MARK: - Statistics

    func getStats() -> KeyboardStats {
        let uniqueWords = Set(learnedPhrases.keys.flatMap { $0.split(separator: " ") })

        return KeyboardStats(
            totalPhrases: learnedPhrases.count,
            totalReplacements: customReplacements.count,
            vocabularySize: uniqueWords.count,
            writingStyle: writingStyle
        )
    }

    // MARK: - Data Clearing

    func clearAllData() {
        learnedPhrases.removeAll()
        customReplacements.removeAll()
        writingStyle = .casual
        saveData()

        UserDefaults.standard.removeObject(forKey: "keyboard_learned_phrases")
        UserDefaults.standard.removeObject(forKey: "keyboard_replacements")
        UserDefaults.standard.removeObject(forKey: "keyboard_writing_style")
    }

    func clearLearnedPhrases() {
        learnedPhrases.removeAll()
        saveData()
    }

    func clearReplacements() {
        customReplacements.removeAll()
        saveData()
    }
}
