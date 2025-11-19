//
//  ProactiveAssistant.swift
//  HuggingChat-iOS
//
//  Proactive suggestions based on context, memory, and behavior patterns
//

import Foundation
import Observation

@Observable
class ProactiveAssistant {
    static let shared = ProactiveAssistant()

    var currentSuggestions: [ProactiveSuggestion] = []
    var isEnabled = true

    private let memoryManager = MemoryManager.shared
    private let contextProvider = ContextProvider.shared
    private let behaviorAnalyzer = UserBehaviorAnalyzer.shared

    private init() {
        loadSettings()
    }

    // MARK: - Generate Suggestions

    func generateSuggestions() -> [ProactiveSuggestion] {
        guard isEnabled else { return [] }

        var suggestions: [ProactiveSuggestion] = []

        // Context-based suggestions
        suggestions.append(contentsOf: getContextBasedSuggestions())

        // Pattern-based suggestions
        suggestions.append(contentsOf: getPatternBasedSuggestions())

        // Memory-based suggestions
        suggestions.append(contentsOf: getMemoryBasedSuggestions())

        // Time-based suggestions
        suggestions.append(contentsOf: getTimeBasedSuggestions())

        // Clipboard-based suggestions
        suggestions.append(contentsOf: getClipboardBasedSuggestions())

        // Sort by relevance score
        suggestions.sort { $0.relevanceScore > $1.relevanceScore }

        // Keep top 5
        currentSuggestions = Array(suggestions.prefix(5))

        return currentSuggestions
    }

    // MARK: - Context-Based Suggestions

    private func getContextBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        let context = contextProvider.getCurrentContext()

        // Low battery suggestion
        if context.batteryLevel < 0.2 && !context.isLowPowerMode {
            suggestions.append(ProactiveSuggestion(
                type: .tip,
                title: "Enable Low Power Mode",
                description: "Your battery is low. Consider using local models to save power.",
                action: "switch_to_local_model",
                relevanceScore: 0.8,
                icon: "battery.25"
            ))
        }

        // Network suggestion
        if context.networkType == .offline {
            suggestions.append(ProactiveSuggestion(
                type: .tip,
                title: "You're Offline",
                description: "Use local models to continue chatting without internet.",
                action: "enable_local_model",
                relevanceScore: 0.9,
                icon: "wifi.slash"
            ))
        }

        return suggestions
    }

    // MARK: - Pattern-Based Suggestions

    private func getPatternBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        let patterns = behaviorAnalyzer.identifiedPatterns

        // Frequent web search pattern
        if let webSearchPattern = patterns.first(where: { $0.name == "frequent_web_search" }),
           webSearchPattern.frequency > 0.7 {
            suggestions.append(ProactiveSuggestion(
                type: .preference,
                title: "Auto-Enable Web Search",
                description: "You often use web search. Want to enable it by default?",
                action: "auto_enable_web_search",
                relevanceScore: webSearchPattern.confidence,
                icon: "magnifyingglass.circle.fill"
            ))
        }

        // Preferred model pattern
        if let modelPattern = patterns.first(where: { $0.name == "preferred_model" }) {
            suggestions.append(ProactiveSuggestion(
                type: .preference,
                title: "Set Default Model",
                description: modelPattern.suggestion,
                action: "set_default_model",
                relevanceScore: modelPattern.confidence,
                icon: "cpu"
            ))
        }

        // Frequent attachments
        if let attachmentPattern = patterns.first(where: { $0.name == "frequent_attachments" }),
           attachmentPattern.frequency > 0.4 {
            suggestions.append(ProactiveSuggestion(
                type: .feature,
                title: "Try Vision Analysis",
                description: "Automatically analyze your images for better context.",
                action: "enable_vision_analysis",
                relevanceScore: attachmentPattern.confidence,
                icon: "eye.fill"
            ))
        }

        return suggestions
    }

    // MARK: - Memory-Based Suggestions

    private func getMemoryBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        // Get recent important memories
        let preferences = memoryManager.getMemoriesByType(.preference, limit: 10)

        // Suggest based on past preferences
        for preference in preferences where preference.importance > 0.7 {
            if preference.content.contains("theme") {
                suggestions.append(ProactiveSuggestion(
                    type: .reminder,
                    title: "Customize Theme",
                    description: "You previously showed interest in themes. Check out the latest options.",
                    action: "open_theme_settings",
                    relevanceScore: preference.importance * 0.6,
                    icon: "paintbrush.fill"
                ))
            }
        }

        // Get conversation patterns from memory
        let conversationMemories = memoryManager.getMemoriesByType(.conversation, limit: 20)

        let topics = conversationMemories.flatMap { $0.tags }
        let topicCounts = Dictionary(grouping: topics) { $0 }.mapValues { $0.count }

        if let frequentTopic = topicCounts.max(by: { $0.value < $1.value }),
           frequentTopic.value > 5 {
            suggestions.append(ProactiveSuggestion(
                type: .quickAction,
                title: "Continue Learning",
                description: "You often discuss \(frequentTopic.key). Start a new conversation about it?",
                action: "start_conversation_about_\(frequentTopic.key)",
                relevanceScore: 0.7,
                icon: "lightbulb.fill"
            ))
        }

        return suggestions
    }

    // MARK: - Time-Based Suggestions

    private func getTimeBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        let context = contextProvider.getCurrentContext()

        switch context.timeOfDay {
        case .morning:
            // Morning routine suggestion
            let morningPatterns = behaviorAnalyzer.identifiedPatterns.filter {
                $0.name.contains("morning")
            }

            if !morningPatterns.isEmpty {
                suggestions.append(ProactiveSuggestion(
                    type: .quickAction,
                    title: "Good Morning!",
                    description: "Start your daily AI chat session?",
                    action: "start_new_conversation",
                    relevanceScore: 0.6,
                    icon: "sunrise.fill"
                ))
            }

        case .night:
            // Night review suggestion
            suggestions.append(ProactiveSuggestion(
                type: .tip,
                title: "Review Today's Insights",
                description: "Look back at today's conversations and learnings.",
                action: "review_conversations",
                relevanceScore: 0.5,
                icon: "moon.stars.fill"
            ))

        default:
            break
        }

        return suggestions
    }

    // MARK: - Clipboard-Based Suggestions

    private func getClipboardBasedSuggestions() -> [ProactiveSuggestion] {
        var suggestions: [ProactiveSuggestion] = []

        let clipboardHistory = contextProvider.getClipboardHistory(limit: 3)

        if let recentClip = clipboardHistory.first {
            // URL in clipboard
            if recentClip.content.starts(with: "http") {
                suggestions.append(ProactiveSuggestion(
                    type: .quickAction,
                    title: "Ask About This URL",
                    description: "I noticed a URL in your clipboard. Want to discuss it?",
                    action: "paste_url_and_ask",
                    relevanceScore: 0.75,
                    icon: "link.circle.fill"
                ))
            }

            // Code in clipboard
            else if recentClip.content.contains("func ") || recentClip.content.contains("class ") {
                suggestions.append(ProactiveSuggestion(
                    type: .quickAction,
                    title: "Explain This Code",
                    description: "I can help explain or improve the code in your clipboard.",
                    action: "paste_code_and_explain",
                    relevanceScore: 0.8,
                    icon: "chevron.left.forwardslash.chevron.right"
                ))
            }

            // Long text in clipboard
            else if recentClip.content.count > 200 {
                suggestions.append(ProactiveSuggestion(
                    type: .quickAction,
                    title: "Summarize Clipboard",
                    description: "Want me to summarize the text in your clipboard?",
                    action: "paste_and_summarize",
                    relevanceScore: 0.7,
                    icon: "doc.text.fill"
                ))
            }
        }

        return suggestions
    }

    // MARK: - Execute Suggestion

    func executeSuggestion(_ suggestion: ProactiveSuggestion) {
        // Track the action
        behaviorAnalyzer.trackFeatureUsed("proactive_suggestion", context: suggestion.action)

        // Mark suggestion as used in memory
        memoryManager.storeMemory(Memory(
            type: .interaction,
            content: "Used suggestion: \(suggestion.title)",
            context: suggestion.description,
            importance: 0.6,
            tags: ["suggestion", suggestion.type.rawValue]
        ))
    }

    func dismissSuggestion(_ suggestion: ProactiveSuggestion) {
        // Remove from current suggestions
        currentSuggestions.removeAll { $0.id == suggestion.id }

        // Store as memory with low importance
        memoryManager.storeMemory(Memory(
            type: .interaction,
            content: "Dismissed suggestion: \(suggestion.title)",
            context: suggestion.description,
            importance: 0.2,
            tags: ["suggestion", "dismissed"]
        ))
    }

    // MARK: - Settings

    func toggleProactive(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "proactiveAssistantEnabled")

        if enabled {
            generateSuggestions()
        } else {
            currentSuggestions = []
        }
    }

    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "proactiveAssistantEnabled")
        if !UserDefaults.standard.object(forKey: "proactiveAssistantEnabled") {
            isEnabled = true // Default to enabled
        }
    }
}

// MARK: - Supporting Types

struct ProactiveSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let action: String
    let relevanceScore: Double // 0.0 to 1.0
    let icon: String
    let timestamp = Date()

    enum SuggestionType: String {
        case quickAction = "Quick Action"
        case tip = "Tip"
        case feature = "Feature"
        case preference = "Preference"
        case reminder = "Reminder"
    }
}
