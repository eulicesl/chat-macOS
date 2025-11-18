//
//  WritingToolsManager.swift
//  HuggingChat-iOS
//
//  Apple Intelligence Writing Tools integration (iOS 18+)
//

import SwiftUI
import NaturalLanguage

@Observable
class WritingToolsManager {
    static let shared = WritingToolsManager()

    private init() {}

    // MARK: - Writing Tools Features

    /// Enhance text using Apple Intelligence
    func enhanceText(_ text: String) -> String {
        // In iOS 18+, this would integrate with Apple Intelligence
        // For now, we'll use NaturalLanguage framework
        return text
    }

    /// Proofread and suggest corrections
    func proofread(_ text: String) -> [TextSuggestion] {
        var suggestions: [TextSuggestion] = []

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            if let tag = tag {
                // Check for potential issues
                if tag == .verb {
                    // Could check for grammar issues
                }
            }
            return true
        }

        return suggestions
    }

    /// Summarize text
    func summarize(_ text: String, maxLength: Int = 100) -> String {
        let sentences = text.components(separatedBy: ". ")

        if sentences.count <= 2 {
            return text
        }

        // Simple summarization: take first few sentences
        let summaryCount = min(2, sentences.count)
        return sentences.prefix(summaryCount).joined(separator: ". ") + "."
    }

    /// Change tone of text
    func changeTone(_ text: String, to tone: WritingTone) -> String {
        // In iOS 18+, this would use Apple Intelligence
        // For now, return original text with note
        return text
    }

    /// Generate smart replies
    func generateSmartReplies(for message: String) -> [String] {
        let lowercaseMessage = message.lowercased()

        // Simple smart reply generation
        var replies: [String] = []

        if lowercaseMessage.contains("how are") || lowercaseMessage.contains("how's") {
            replies = ["I'm doing well, thanks!", "Great! How about you?", "Pretty good!"]
        } else if lowercaseMessage.contains("thank") {
            replies = ["You're welcome!", "Happy to help!", "Anytime!"]
        } else if lowercaseMessage.contains("?") {
            replies = ["Let me think about that", "That's a great question", "I'm not sure"]
        } else {
            replies = ["That makes sense", "Interesting!", "Tell me more"]
        }

        return replies
    }

    /// Detect language
    func detectLanguage(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        return recognizer.dominantLanguage?.rawValue
    }

    /// Extract key concepts
    func extractKeyConcepts(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var concepts: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag, tag != .otherWord {
                concepts.append(String(text[range]))
            }
            return true
        }

        return concepts
    }

    /// Check sentiment
    func analyzeSentiment(_ text: String) -> SentimentScore {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var totalScore = 0.0
        var count = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, range in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        let averageScore = count > 0 ? totalScore / Double(count) : 0.0

        if averageScore > 0.3 {
            return .positive
        } else if averageScore < -0.3 {
            return .negative
        } else {
            return .neutral
        }
    }
}

// MARK: - Supporting Types

enum WritingTone: String, CaseIterable {
    case professional = "Professional"
    case casual = "Casual"
    case friendly = "Friendly"
    case formal = "Formal"
    case concise = "Concise"
}

struct TextSuggestion: Identifiable {
    let id = UUID()
    let range: Range<String.Index>
    let original: String
    let suggestion: String
    let reason: String
}

enum SentimentScore {
    case positive
    case neutral
    case negative

    var emoji: String {
        switch self {
        case .positive: return "😊"
        case .neutral: return "😐"
        case .negative: return "😔"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .neutral: return .gray
        case .negative: return .red
        }
    }
}
