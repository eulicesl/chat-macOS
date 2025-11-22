//
//  ConversationViewModel+Memory.swift
//  HuggingChat-iOS
//
//  Memory and learning extensions for ConversationViewModel
//

import Foundation

extension ConversationViewModel {
    // MARK: - Memory Integration

    func trackMessageSent(_ text: String, modelId: String) {
        // Track in behavior analyzer
        let context = ContextProvider.shared.getCurrentContext()

        UserBehaviorAnalyzer.shared.trackMessageSent(
            modelId: modelId,
            hasWebSearch: useWebSearch,
            hasAttachments: false,
            timeOfDay: context.timeOfDay
        )

        // Store in memory
        if let conversationId = conversation?.id {
            Task {
                await MemoryManager.shared.storeConversationMemory(
                    conversationId: conversationId,
                    content: text,
                    context: "Model: \(modelId), WebSearch: \(useWebSearch)",
                    importance: 0.5,
                    tags: await extractTags(from: text)
                )
            }
        }

        // Update tips
        TipsManager.shared.incrementMessagesSent()

        if useWebSearch {
            TipsManager.shared.markWebSearchUsed()
        }
    }

    func trackResponseReceived(_ response: String, modelId: String) async {
        // Store assistant response in memory
        if let conversationId = conversation?.id {
            await MemoryManager.shared.storeConversationMemory(
                conversationId: conversationId,
                content: response,
                context: "Assistant response from \(modelId)",
                importance: 0.6,
                tags: await extractTags(from: response)
            )
        }

        // Extract and store facts/insights
        let keywords = await SemanticSearch.shared.extractKeywords(from: response, limit: 5)

        for keyword in keywords {
            MemoryManager.shared.storeMemory(Memory(
                type: .fact,
                content: keyword,
                context: "From conversation",
                importance: 0.4,
                tags: ["keyword", "fact"],
                associatedConversationId: conversation?.id
            ))
        }
    }

    func trackConversationCreated(modelId: String) {
        UserBehaviorAnalyzer.shared.trackFeatureUsed("create_conversation", context: modelId)

        UserBehaviorAnalyzer.shared.trackPreferenceChange(
            key: "last_used_model",
            value: modelId
        )

        TipsManager.shared.incrementConversationsCreated()
    }

    func trackFeatureToggled(_ feature: String, enabled: Bool) {
        UserBehaviorAnalyzer.shared.trackFeatureUsed(
            feature,
            context: enabled ? "enabled" : "disabled"
        )

        if feature == "web_search" && enabled {
            TipsManager.shared.markWebSearchUsed()
        }
    }

    // MARK: - Context Awareness

    func getContextualPrompt() -> String? {
        let context = ContextProvider.shared.getCurrentContext()

        // Check clipboard for relevant content
        if let clipboardContent = context.clipboardContent,
           !clipboardContent.isEmpty,
           clipboardContent.count < 500 {
            return """
            I noticed you have this in your clipboard:

            \(clipboardContent)

            Would you like to discuss it?
            """
        }

        return nil
    }

    func getRelevantMemories(for query: String) async -> [Memory] {
        let allMemories = MemoryManager.shared.recentMemories

        return await SemanticSearch.shared.searchMemories(
            query: query,
            in: allMemories,
            limit: 5
        ).map { $0.memory }
    }

    func enrichPromptWithContext(_ prompt: String) -> String {
        var enrichedPrompt = prompt

        // Get relevant memories
        Task {
            let relevantMemories = await getRelevantMemories(for: prompt)
            if !relevantMemories.isEmpty {
                let memoryContext = relevantMemories
                    .prefix(3)
                    .map { "- \($0.content)" }
                    .joined(separator: "\n")

                enrichedPrompt += """


                [Context from previous conversations:
                \(memoryContext)]
                """
            }

            // Add device context if relevant
            let context = ContextProvider.shared.getCurrentContext()

            if context.isLowPowerMode {
                enrichedPrompt += "\n\n[Note: Device is in low power mode]"
            }
        }

        return enrichedPrompt
    }

    // MARK: - Private Helpers

    private func extractTags(from text: String) async -> [String] {
        let keywords = await SemanticSearch.shared.extractKeywords(from: text, limit: 3)

        var tags = keywords

        // Add domain-specific tags
        if text.lowercased().contains("code") || text.contains("func ") || text.contains("class ") {
            tags.append("programming")
        }

        if text.lowercased().contains("how to") || text.lowercased().contains("explain") {
            tags.append("question")
        }

        return Array(Set(tags)) // Remove duplicates
    }
}

