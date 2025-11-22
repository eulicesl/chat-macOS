//
//  UserBehaviorAnalyzer.swift
//  HuggingChat-iOS
//
//  Analyzes user behavior patterns to provide proactive assistance
//

import Foundation
import Observation

@Observable
final class UserBehaviorAnalyzer: @unchecked Sendable {
    static let shared = UserBehaviorAnalyzer()

    var identifiedPatterns: [BehaviorPattern] = []
    var userPreferences: [String: Any] = [:]
    var interactionHistory: [UserInteraction] = []

    private init() {
        loadPreferences()
    }

    // MARK: - Track Interactions

    func trackInteraction(_ interaction: UserInteraction) {
        interactionHistory.append(interaction)

        // Keep only last 1000 interactions
        if interactionHistory.count > 1000 {
            interactionHistory = Array(interactionHistory.suffix(1000))
        }

        // Store in memory
        MemoryManager.shared.storeMemory(Memory(
            type: .interaction,
            content: interaction.action,
            context: interaction.context,
            importance: 0.3,
            tags: [interaction.category, "interaction"]
        ))

        // Analyze for patterns
        analyzePatterns()
    }

    func trackMessageSent(modelId: String, hasWebSearch: Bool, hasAttachments: Bool, timeOfDay: TimeOfDay) {
        let interaction = UserInteraction(
            action: "message_sent",
            category: "messaging",
            context: "Model: \(modelId), WebSearch: \(hasWebSearch), Attachments: \(hasAttachments)",
            metadata: [
                "model": modelId,
                "webSearch": hasWebSearch,
                "hasAttachments": hasAttachments,
                "timeOfDay": timeOfDay.rawValue
            ]
        )
        trackInteraction(interaction)
    }

    func trackFeatureUsed(_ feature: String, context: String? = nil) {
        let interaction = UserInteraction(
            action: "feature_used",
            category: "features",
            context: context,
            metadata: ["feature": feature]
        )
        trackInteraction(interaction)
    }

    func trackPreferenceChange(key: String, value: Any) {
        userPreferences[key] = value
        savePreferences()

        // Store as memory
        MemoryManager.shared.storeUserPreference(
            key: key,
            value: "\(value)",
            importance: 0.7
        )
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns() {
        // Analyze message sending patterns
        analyzeSendingPatterns()

        // Analyze feature usage
        analyzeFeatureUsage()

        // Analyze timing patterns
        analyzeTimingPatterns()

        // Analyze model preferences
        analyzeModelPreferences()
    }

    private func analyzeSendingPatterns() {
        let messagingInteractions = interactionHistory.filter { $0.action == "message_sent" }

        // Web search pattern
        let webSearchUsage = messagingInteractions.filter {
            ($0.metadata["webSearch"] as? Bool) == true
        }.count

        let webSearchRate = Double(webSearchUsage) / Double(max(1, messagingInteractions.count))

        if webSearchRate > 0.7 {
            addPattern(BehaviorPattern(
                name: "frequent_web_search",
                description: "User frequently uses web search",
                frequency: webSearchRate,
                confidence: 0.8,
                suggestion: "Auto-enable web search by default"
            ))
        }

        // Attachment pattern
        let attachmentUsage = messagingInteractions.filter {
            ($0.metadata["hasAttachments"] as? Bool) == true
        }.count

        if attachmentUsage > 5 {
            addPattern(BehaviorPattern(
                name: "frequent_attachments",
                description: "User frequently attaches images",
                frequency: Double(attachmentUsage) / Double(max(1, messagingInteractions.count)),
                confidence: 0.7,
                suggestion: "Suggest using Vision analysis features"
            ))
        }
    }

    private func analyzeFeatureUsage() {
        let featureInteractions = interactionHistory.filter { $0.action == "feature_used" }

        let featureCounts = Dictionary(grouping: featureInteractions) { interaction in
            interaction.metadata["feature"] as? String ?? "unknown"
        }.mapValues { $0.count }

        for (feature, count) in featureCounts where count > 10 {
            addPattern(BehaviorPattern(
                name: "frequent_\(feature)",
                description: "User frequently uses \(feature)",
                frequency: Double(count) / Double(max(1, featureInteractions.count)),
                confidence: 0.75,
                suggestion: "Optimize \(feature) for quick access"
            ))
        }
    }

    private func analyzeTimingPatterns() {
        let timeDistribution = Dictionary(grouping: interactionHistory) { interaction in
            if let timeOfDay = interaction.metadata["timeOfDay"] as? String {
                return timeOfDay
            }
            return "unknown"
        }.mapValues { $0.count }

        if let mostActiveTime = timeDistribution.max(by: { $0.value < $1.value }) {
            if Double(mostActiveTime.value) / Double(max(1, interactionHistory.count)) > 0.5 {
                addPattern(BehaviorPattern(
                    name: "active_time_\(mostActiveTime.key)",
                    description: "User most active during \(mostActiveTime.key)",
                    frequency: Double(mostActiveTime.value) / Double(max(1, interactionHistory.count)),
                    confidence: 0.8,
                    suggestion: "Send notifications/tips during \(mostActiveTime.key)"
                ))
            }
        }
    }

    private func analyzeModelPreferences() {
        let modelUsage = interactionHistory
            .compactMap { $0.metadata["model"] as? String }
            .reduce(into: [:]) { counts, model in
                counts[model, default: 0] += 1
            }

        if let favoriteModel = modelUsage.max(by: { $0.value < $1.value }),
           Double(favoriteModel.value) / Double(max(1, modelUsage.values.reduce(0, +))) > 0.6 {

            addPattern(BehaviorPattern(
                name: "preferred_model",
                description: "User prefers \(favoriteModel.key)",
                frequency: Double(favoriteModel.value) / Double(max(1, modelUsage.values.reduce(0, +))),
                confidence: 0.9,
                suggestion: "Set \(favoriteModel.key) as default model"
            ))
        }
    }

    private func addPattern(_ pattern: BehaviorPattern) {
        // Remove existing pattern with same name
        identifiedPatterns.removeAll { $0.name == pattern.name }

        // Add new pattern
        identifiedPatterns.append(pattern)

        // Store in memory
        MemoryManager.shared.storeUserPattern(
            pattern: pattern.description,
            frequency: Int(pattern.frequency * 100),
            importance: pattern.confidence
        )
    }

    // MARK: - Predictions

    func predictNextAction() -> PredictedAction? {
        let context = ContextProvider.shared.getCurrentContext()

        // Based on time of day
        if context.timeOfDay == .morning {
            if identifiedPatterns.contains(where: { $0.name.contains("morning") }) {
                return PredictedAction(
                    action: "start_new_conversation",
                    confidence: 0.7,
                    reason: "User typically starts conversations in the morning"
                )
            }
        }

        // Based on clipboard
        if let clipboardContent = context.clipboardContent, !clipboardContent.isEmpty {
            return PredictedAction(
                action: "paste_and_ask",
                confidence: 0.6,
                reason: "Clipboard contains content that might be relevant"
            )
        }

        // Based on patterns
        if let frequentFeature = identifiedPatterns.first(where: { $0.frequency > 0.5 }) {
            return PredictedAction(
                action: "suggest_\(frequentFeature.name)",
                confidence: frequentFeature.confidence,
                reason: frequentFeature.suggestion
            )
        }

        return nil
    }

    func shouldSuggestFeature(_ feature: String) -> Bool {
        let featureUsage = interactionHistory.filter {
            ($0.metadata["feature"] as? String) == feature
        }.count

        // Suggest if never used or used less than 3 times
        return featureUsage < 3 && interactionHistory.count > 10
    }

    // MARK: - Persistence

    private func savePreferences() {
        if let data = try? JSONSerialization.data(withJSONObject: userPreferences) {
            UserDefaults.standard.set(data, forKey: "userBehaviorPreferences")
        }
    }

    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "userBehaviorPreferences"),
           let prefs = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            userPreferences = prefs
        }
    }
}

// MARK: - Supporting Types

struct UserInteraction: Codable {
    let id = UUID()
    let timestamp = Date()
    let action: String
    let category: String
    let context: String?
    let metadata: [String: Any]

    enum CodingKeys: String, CodingKey {
        case action, category, context
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(context, forKey: .context)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(String.self, forKey: .action)
        category = try container.decode(String.self, forKey: .category)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        metadata = [:]
    }

    init(action: String, category: String, context: String?, metadata: [String: Any] = [:]) {
        self.action = action
        self.category = category
        self.context = context
        self.metadata = metadata
    }
}

struct BehaviorPattern: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let frequency: Double // 0.0 to 1.0
    let confidence: Double // 0.0 to 1.0
    let suggestion: String
}

struct PredictedAction {
    let action: String
    let confidence: Double
    let reason: String
}
