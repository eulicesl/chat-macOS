//
//  KeyboardMemoryService.swift
//  HuggingChatKeyboard
//
//  Advanced memory integration for keyboard
//  Learns writing style, remembers phrases, provides personalized suggestions
//

import Foundation
import Observation

/// Service that integrates Memory System with keyboard for personalized suggestions
@Observable
class KeyboardMemoryService {
    static let shared = KeyboardMemoryService()

    // Memory integration (access via App Groups)
    private let sharedData = SharedDataManager.shared

    // Learned patterns
    var frequentPhrases: [FrequentPhrase] = []
    var writingStyle: WritingStyle = .neutral
    var customReplacements: [String: String] = [:]
    var userVocabulary: Set<String> = []

    // State
    var isLearningEnabled: Bool = true
    var suggestionConfidenceThreshold: Double = 0.6

    private init() {
        loadLearnedData()
    }

    // MARK: - Learning

    /// Learns from user's text input
    func learnFromText(_ text: String) {
        guard isLearningEnabled else { return }
        guard text.count > 3 else { return }

        // Extract phrases (2-5 words)
        extractAndLearnPhrases(from: text)

        // Learn writing style
        analyzeWritingStyle(text)

        // Build vocabulary
        addToVocabulary(text)

        // Save learned data
        saveLearnedData()
    }

    /// Learns from AI completions user keeps
    func learnFromCompletion(_ completion: AICompletion) {
        guard isLearningEnabled else { return }

        // If user used this completion, it's a good pattern
        let phrase = FrequentPhrase(
            text: completion.completion,
            frequency: 1,
            context: completion.prompt,
            lastUsed: Date()
        )

        if let index = frequentPhrases.firstIndex(where: { $0.text == phrase.text }) {
            frequentPhrases[index].frequency += 1
            frequentPhrases[index].lastUsed = Date()
        } else {
            frequentPhrases.append(phrase)
        }

        saveLearnedData()
    }

    // MARK: - Suggestions

    /// Gets personalized suggestions based on context
    func getPersonalizedSuggestions(for context: String) -> [PersonalizedSuggestion] {
        var suggestions: [PersonalizedSuggestion] = []

        // Check frequent phrases
        let phraseSuggestions = suggestFrequentPhrases(matching: context)
        suggestions.append(contentsOf: phraseSuggestions)

        // Check custom replacements
        if let replacement = getCustomReplacement(for: context) {
            suggestions.append(PersonalizedSuggestion(
                text: replacement,
                type: .customReplacement,
                confidence: 1.0,
                source: .userDefined
            ))
        }

        // Writing style adjustments
        if let styleAdjustment = adjustForWritingStyle(context) {
            suggestions.append(styleAdjustment)
        }

        // Filter by confidence and sort
        return suggestions
            .filter { $0.confidence >= suggestionConfidenceThreshold }
            .sorted { $0.confidence > $1.confidence }
    }

    /// Gets phrase completions
    func getPhraseCompletions(for partial: String) -> [String] {
        guard partial.count >= 2 else { return [] }

        return frequentPhrases
            .filter { $0.text.lowercased().hasPrefix(partial.lowercased()) }
            .sorted { $0.frequency > $1.frequency }
            .prefix(5)
            .map { $0.text }
    }

    // MARK: - Custom Replacements

    /// Adds a custom text replacement
    func addCustomReplacement(shortcut: String, replacement: String) {
        customReplacements[shortcut] = replacement
        saveLearnedData()
    }

    /// Removes a custom replacement
    func removeCustomReplacement(shortcut: String) {
        customReplacements.removeValue(forKey: shortcut)
        saveLearnedData()
    }

    /// Gets replacement for shortcut
    func getCustomReplacement(for shortcut: String) -> String? {
        customReplacements[shortcut]
    }

    // MARK: - Writing Style

    /// Analyzes and updates writing style
    private func analyzeWritingStyle(_ text: String) {
        let lowercased = text.lowercased()

        // Detect formal vs casual
        let formalIndicators = ["however", "furthermore", "therefore", "thus", "regarding"]
        let casualIndicators = ["lol", "btw", "gonna", "wanna", "hey", "cool"]

        let formalScore = formalIndicators.filter { lowercased.contains($0) }.count
        let casualScore = casualIndicators.filter { lowercased.contains($0) }.count

        if formalScore > casualScore {
            writingStyle = .formal
        } else if casualScore > formalScore {
            writingStyle = .casual
        }
    }

    /// Adjusts suggestion based on writing style
    private func adjustForWritingStyle(_ text: String) -> PersonalizedSuggestion? {
        // If user writes formally, suggest formal alternatives
        // If user writes casually, suggest casual alternatives

        let lowercased = text.lowercased()

        if writingStyle == .formal {
            if lowercased.contains("hi ") || lowercased.hasSuffix("hi") {
                return PersonalizedSuggestion(
                    text: "Hello",
                    type: .styleAdjustment,
                    confidence: 0.7,
                    source: .learned
                )
            }
        } else if writingStyle == .casual {
            if lowercased.contains("hello ") {
                return PersonalizedSuggestion(
                    text: "Hey",
                    type: .styleAdjustment,
                    confidence: 0.7,
                    source: .learned
                )
            }
        }

        return nil
    }

    // MARK: - Phrase Learning

    private func extractAndLearnPhrases(from text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Extract 2-5 word phrases
        for length in 2...5 {
            for i in 0...(words.count - length) {
                let phrase = words[i..<(i + length)].joined(separator: " ")

                // Only learn meaningful phrases (skip very common words)
                guard !isCommonPhrase(phrase) else { continue }

                if let index = frequentPhrases.firstIndex(where: { $0.text.lowercased() == phrase.lowercased() }) {
                    frequentPhrases[index].frequency += 1
                    frequentPhrases[index].lastUsed = Date()
                } else if frequentPhrases.count < 1000 { // Limit storage
                    frequentPhrases.append(FrequentPhrase(
                        text: phrase,
                        frequency: 1,
                        context: text,
                        lastUsed: Date()
                    ))
                }
            }
        }

        // Clean up old/infrequent phrases periodically
        if frequentPhrases.count > 1000 {
            cleanupPhrases()
        }
    }

    private func isCommonPhrase(_ phrase: String) -> Bool {
        let commonPhrases = ["the the", "a a", "is is", "of the the", "to to"]
        return commonPhrases.contains(phrase.lowercased())
    }

    private func cleanupPhrases() {
        // Keep only top 500 phrases by frequency and recency
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        frequentPhrases = frequentPhrases
            .filter { $0.lastUsed > thirtyDaysAgo || $0.frequency > 3 }
            .sorted { $0.frequency > $1.frequency }
            .prefix(500)
            .map { $0 }
    }

    private func suggestFrequentPhrases(matching context: String) -> [PersonalizedSuggestion] {
        let words = context.components(separatedBy: .whitespacesAndNewlines)
        guard let lastWord = words.last, !lastWord.isEmpty else {
            return []
        }

        return frequentPhrases
            .filter { phrase in
                phrase.text.lowercased().hasPrefix(lastWord.lowercased()) ||
                phrase.text.lowercased().contains(" \(lastWord.lowercased())")
            }
            .prefix(3)
            .map { phrase in
                PersonalizedSuggestion(
                    text: phrase.text,
                    type: .frequentPhrase,
                    confidence: min(Double(phrase.frequency) / 10.0, 0.95),
                    source: .learned
                )
            }
    }

    // MARK: - Vocabulary

    private func addToVocabulary(_ text: String) {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { $0.count > 3 } // Only words with 4+ characters

        userVocabulary.formUnion(words)

        // Limit vocabulary size
        if userVocabulary.count > 5000 {
            // Keep random 4000 words (simple cleanup)
            userVocabulary = Set(userVocabulary.shuffled().prefix(4000))
        }
    }

    /// Checks if a word is in user's vocabulary
    func isInVocabulary(_ word: String) -> Bool {
        userVocabulary.contains(word.lowercased())
    }

    // MARK: - Persistence

    private func loadLearnedData() {
        do {
            // Load frequent phrases
            if let phrasesData = try? sharedData.loadFromSharedContainer(filename: "keyboard_phrases.json"),
               let phrases = try? JSONDecoder().decode([FrequentPhrase].self, from: phrasesData) {
                frequentPhrases = phrases
            }

            // Load custom replacements
            if let replacementsData = try? sharedData.loadFromSharedContainer(filename: "keyboard_replacements.json"),
               let replacements = try? JSONDecoder().decode([String: String].self, from: replacementsData) {
                customReplacements = replacements
            }

            // Load vocabulary
            if let vocabData = try? sharedData.loadFromSharedContainer(filename: "keyboard_vocabulary.json"),
               let vocab = try? JSONDecoder().decode(Set<String>.self, from: vocabData) {
                userVocabulary = vocab
            }

            // Load writing style
            if let styleData = try? sharedData.loadFromSharedContainer(filename: "keyboard_style.json"),
               let style = try? JSONDecoder().decode(WritingStyle.self, from: styleData) {
                writingStyle = style
            }
        }
    }

    private func saveLearnedData() {
        // Save frequent phrases
        if let phrasesData = try? JSONEncoder().encode(frequentPhrases) {
            try? sharedData.saveToSharedContainer(data: phrasesData, filename: "keyboard_phrases.json")
        }

        // Save custom replacements
        if let replacementsData = try? JSONEncoder().encode(customReplacements) {
            try? sharedData.saveToSharedContainer(data: replacementsData, filename: "keyboard_replacements.json")
        }

        // Save vocabulary
        if let vocabData = try? JSONEncoder().encode(userVocabulary) {
            try? sharedData.saveToSharedContainer(data: vocabData, filename: "keyboard_vocabulary.json")
        }

        // Save writing style
        if let styleData = try? JSONEncoder().encode(writingStyle) {
            try? sharedData.saveToSharedContainer(data: styleData, filename: "keyboard_style.json")
        }
    }

    // MARK: - Data Management

    /// Clears all learned data
    func clearAllData() {
        frequentPhrases.removeAll()
        customReplacements.removeAll()
        userVocabulary.removeAll()
        writingStyle = .neutral

        // Delete files
        try? sharedData.deleteFromSharedContainer(filename: "keyboard_phrases.json")
        try? sharedData.deleteFromSharedContainer(filename: "keyboard_replacements.json")
        try? sharedData.deleteFromSharedContainer(filename: "keyboard_vocabulary.json")
        try? sharedData.deleteFromSharedContainer(filename: "keyboard_style.json")
    }

    /// Exports learned data
    func exportData() -> Data? {
        let export = KeyboardMemoryExport(
            phrases: frequentPhrases,
            replacements: customReplacements,
            vocabulary: Array(userVocabulary),
            writingStyle: writingStyle
        )

        return try? JSONEncoder().encode(export)
    }

    /// Imports learned data
    func importData(_ data: Data) throws {
        let export = try JSONDecoder().decode(KeyboardMemoryExport.self, from: data)

        frequentPhrases = export.phrases
        customReplacements = export.replacements
        userVocabulary = Set(export.vocabulary)
        writingStyle = export.writingStyle

        saveLearnedData()
    }

    /// Gets statistics
    func getStats() -> MemoryStats {
        MemoryStats(
            totalPhrases: frequentPhrases.count,
            totalReplacements: customReplacements.count,
            vocabularySize: userVocabulary.count,
            writingStyle: writingStyle,
            isLearningEnabled: isLearningEnabled
        )
    }
}

// MARK: - Supporting Types

struct FrequentPhrase: Codable, Identifiable {
    let id = UUID()
    var text: String
    var frequency: Int
    var context: String
    var lastUsed: Date

    enum CodingKeys: String, CodingKey {
        case text, frequency, context, lastUsed
    }
}

struct PersonalizedSuggestion {
    let text: String
    let type: SuggestionType
    let confidence: Double
    let source: SuggestionSource

    enum SuggestionType {
        case frequentPhrase
        case customReplacement
        case styleAdjustment
        case vocabularyCompletion
    }

    enum SuggestionSource {
        case learned
        case userDefined
        case ai
    }
}

enum WritingStyle: String, Codable {
    case formal = "Formal"
    case casual = "Casual"
    case neutral = "Neutral"
}

struct KeyboardMemoryExport: Codable {
    let phrases: [FrequentPhrase]
    let replacements: [String: String]
    let vocabulary: [String]
    let writingStyle: WritingStyle
}

struct MemoryStats {
    let totalPhrases: Int
    let totalReplacements: Int
    let vocabularySize: Int
    let writingStyle: WritingStyle
    let isLearningEnabled: Bool
}
