//
//  CommandParser.swift
//  HuggingChatKeyboard
//
//  Parses and executes quick commands
//

import Foundation

/// Parses text input for quick commands and generates AI prompts
class CommandParser {

    // MARK: - Command Detection

    /// Detects if text contains a quick command
    func detectCommand(in text: String) -> DetectedCommand? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)

        // Check for command prefix
        guard trimmed.hasPrefix("/") else {
            return nil
        }

        // Split into command and arguments
        let components = trimmed.components(separatedBy: .whitespaces)
        guard let trigger = components.first else {
            return nil
        }

        let arguments = components.dropFirst().joined(separator: " ")

        return DetectedCommand(
            trigger: trigger,
            arguments: arguments,
            fullText: trimmed
        )
    }

    /// Matches detected command with registered quick commands
    func matchCommand(_ detected: DetectedCommand, from commands: [QuickCommand]) -> QuickCommand? {
        commands.first { $0.trigger.lowercased() == detected.trigger.lowercased() && $0.isEnabled }
    }

    /// Builds AI prompt from command and input
    func buildPrompt(for command: QuickCommand, with input: String) -> String {
        // Replace {input} placeholder with actual input
        var prompt = command.prompt
        prompt = prompt.replacingOccurrences(of: "{input}", with: input)

        // Replace {clipboard} if present
        if prompt.contains("{clipboard}") {
            let clipboard = getClipboardContent()
            prompt = prompt.replacingOccurrences(of: "{clipboard}", with: clipboard)
        }

        return prompt
    }

    // MARK: - Context Extraction

    /// Extracts relevant context from text document proxy
    func extractContext(before: String?, after: String?) -> TextContext {
        let beforeText = before ?? ""
        let afterText = after ?? ""

        return TextContext(
            beforeCursor: beforeText,
            afterCursor: afterText,
            fullText: beforeText + afterText,
            lastSentence: extractLastSentence(from: beforeText),
            lastWord: extractLastWord(from: beforeText),
            isQuestionContext: beforeText.contains("?"),
            isCommandContext: beforeText.contains("/")
        )
    }

    private func extractLastSentence(from text: String) -> String {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        return sentences.last?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private func extractLastWord(from text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        return words.last?.trimmingCharacters(in: .punctuationCharacters) ?? ""
    }

    private func getClipboardContent() -> String {
        #if os(iOS)
        return UIPasteboard.general.string ?? ""
        #else
        return ""
        #endif
    }

    // MARK: - Smart Suggestions

    /// Generates smart suggestions based on context
    func generateSuggestions(for context: TextContext, commands: [QuickCommand]) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Command suggestions
        if context.isCommandContext {
            let lastWord = context.lastWord
            let matchingCommands = commands.filter { cmd in
                cmd.isEnabled && cmd.trigger.lowercased().hasPrefix(lastWord.lowercased())
            }

            suggestions.append(contentsOf: matchingCommands.map { cmd in
                Suggestion(
                    text: cmd.trigger,
                    type: .command,
                    confidence: calculateConfidence(for: cmd.trigger, matching: lastWord),
                    metadata: ["icon": cmd.icon, "description": cmd.prompt]
                )
            })
        }

        // Contextual suggestions
        if context.isQuestionContext {
            suggestions.append(Suggestion(
                text: "/ai",
                type: .command,
                confidence: 0.8,
                metadata: ["icon": "sparkles", "description": "Ask AI"]
            ))
        }

        // Smart completion suggestions
        let completions = generateSmartCompletions(for: context)
        suggestions.append(contentsOf: completions)

        // Sort by confidence
        return suggestions.sorted { $0.confidence > $1.confidence }
    }

    private func generateSmartCompletions(for context: TextContext) -> [Suggestion] {
        var completions: [Suggestion] = []

        let lastSentence = context.lastSentence.lowercased()

        // Common completion patterns
        let patterns: [(pattern: String, completions: [String])] = [
            ("thank", ["Thank you", "Thanks", "Thank you so much"]),
            ("hello", ["Hello", "Hello there", "Hello!"]),
            ("how are", ["How are you?", "How are you doing?"]),
            ("see you", ["See you later", "See you soon"]),
            ("talk to", ["Talk to you later", "Talk to you soon"]),
            ("looking forward", ["Looking forward to hearing from you", "Looking forward to it"])
        ]

        for (pattern, suggestions) in patterns {
            if lastSentence.contains(pattern) {
                completions.append(contentsOf: suggestions.map { suggestion in
                    Suggestion(
                        text: suggestion,
                        type: .completion,
                        confidence: 0.7,
                        metadata: [:]
                    )
                })
            }
        }

        return completions
    }

    private func calculateConfidence(for text: String, matching query: String) -> Double {
        guard !query.isEmpty else { return 0.5 }

        let textLower = text.lowercased()
        let queryLower = query.lowercased()

        // Exact match
        if textLower == queryLower {
            return 1.0
        }

        // Prefix match
        if textLower.hasPrefix(queryLower) {
            let matchRatio = Double(queryLower.count) / Double(textLower.count)
            return 0.7 + (matchRatio * 0.3)
        }

        // Contains match
        if textLower.contains(queryLower) {
            return 0.5
        }

        return 0.3
    }

    // MARK: - Prompt Enhancement

    /// Enhances user prompt with context and memory
    func enhancePrompt(_ prompt: String, with context: TextContext) -> String {
        var enhanced = prompt

        // Add context if relevant
        if !context.fullText.isEmpty && context.fullText.count < 200 {
            enhanced = "Context: \(context.lastSentence)\n\nRequest: \(prompt)"
        }

        return enhanced
    }
}

// MARK: - Supporting Types

struct DetectedCommand {
    let trigger: String
    let arguments: String
    let fullText: String
}

struct TextContext {
    let beforeCursor: String
    let afterCursor: String
    let fullText: String
    let lastSentence: String
    let lastWord: String
    let isQuestionContext: Bool
    let isCommandContext: Bool
}

struct Suggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let confidence: Double
    let metadata: [String: String]
}

enum SuggestionType {
    case command
    case completion
    case smartReply
    case translation
}
