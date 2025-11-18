//
//  ConversationViewModel.swift
//  HuggingChat-iOS
//

import Foundation
import Observation
import Combine

@Observable
class ConversationViewModel {
    var messages: [MessageRow] = []
    var conversation: Conversation?
    var state: ConversationState = .none
    var isInteracting = false
    var errorMessage: String?

    // Settings
    var useWebSearch = false
    var useLocalModel = false

    // Current response tracking
    private var currentResponseId: String?
    private var currentResponseContent = ""

    enum ConversationState {
        case none
        case empty
        case loaded
        case loading
        case generating
        case error(String)
    }

    // MARK: - Conversation Management

    func loadConversation(_ conversation: Conversation) async {
        self.conversation = conversation
        state = .loading

        do {
            let fullConversation = try await NetworkService.shared.getConversation(id: conversation.id)

            await MainActor.run {
                self.conversation = fullConversation
                self.messages = fullConversation.messages.map { message in
                    MessageRow(
                        id: message.id,
                        content: message.content,
                        type: message.author == .user ? .user : .assistant,
                        isInteracting: false,
                        webSearch: message.webSearch,
                        files: message.files,
                        createdAt: message.createdAt
                    )
                }
                self.state = self.messages.isEmpty ? .empty : .loaded
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.state = .error(error.localizedDescription)
            }
        }
    }

    func createNewConversation(modelId: String) async {
        state = .loading

        do {
            let newConversation = try await NetworkService.shared.createConversation(modelId: modelId)

            await MainActor.run {
                self.conversation = newConversation
                self.messages = []
                self.state = .empty
                HuggingChatSession.shared.conversations.insert(newConversation, at: 0)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Message Sending

    func sendMessage(_ text: String, files: [String]? = nil) async {
        guard let conversationId = conversation?.id else {
            errorMessage = "No active conversation"
            return
        }

        // Add user message
        let userMessage = MessageRow(
            id: UUID().uuidString,
            content: text,
            type: .user,
            isInteracting: false,
            files: files,
            createdAt: Date()
        )

        await MainActor.run {
            messages.append(userMessage)
            isInteracting = true
            state = .generating
        }

        // Create placeholder for assistant response
        let assistantId = UUID().uuidString
        currentResponseId = assistantId
        currentResponseContent = ""

        let assistantMessage = MessageRow(
            id: assistantId,
            content: "",
            type: .assistant,
            isInteracting: true,
            createdAt: Date()
        )

        await MainActor.run {
            messages.append(assistantMessage)
        }

        // Stream response
        do {
            let stream = NetworkService.shared.streamMessage(
                conversationId: conversationId,
                prompt: text,
                webSearch: useWebSearch,
                files: files
            )

            for try await jsonString in stream {
                await handleStreamData(jsonString)
            }

            // Mark as complete
            await MainActor.run {
                if let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    var updatedMessage = messages[index]
                    updatedMessage.isInteracting = false
                    messages[index] = updatedMessage
                }
                isInteracting = false
                state = .loaded
                currentResponseId = nil
                currentResponseContent = ""
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.state = .error(error.localizedDescription)
                self.isInteracting = false

                // Remove failed assistant message
                if let index = messages.firstIndex(where: { $0.id == assistantId }) {
                    messages.remove(at: index)
                }
            }
        }
    }

    private func handleStreamData(_ jsonString: String) async {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        await MainActor.run {
            // Handle token
            if let token = json["token"] as? String {
                currentResponseContent += token
                updateCurrentResponse()
            }

            // Handle web search
            if let webSearch = json["webSearch"] as? [String: Any] {
                updateWebSearch(webSearch)
            }

            // Handle completion
            if let type = json["type"] as? String, type == "finalAnswer" {
                if let index = messages.firstIndex(where: { $0.id == currentResponseId }) {
                    var updatedMessage = messages[index]
                    updatedMessage.isInteracting = false
                    messages[index] = updatedMessage
                }
            }
        }
    }

    private func updateCurrentResponse() {
        guard let responseId = currentResponseId,
              let index = messages.firstIndex(where: { $0.id == responseId }) else {
            return
        }

        var updatedMessage = messages[index]
        updatedMessage.content = currentResponseContent
        messages[index] = updatedMessage
    }

    private func updateWebSearch(_ webSearchData: [String: Any]) {
        guard let responseId = currentResponseId,
              let index = messages.firstIndex(where: { $0.id == responseId }) else {
            return
        }

        // Parse web search data
        // This would need to match the structure from the API
        var updatedMessage = messages[index]
        // updatedMessage.webSearch = ... (parse webSearchData)
        messages[index] = updatedMessage
    }

    // MARK: - Conversation Actions

    func clearConversation() async {
        guard let conv = conversation else { return }

        do {
            try await NetworkService.shared.deleteConversation(id: conv.id)

            await MainActor.run {
                messages = []
                conversation = nil
                state = .none
                HuggingChatSession.shared.conversations.removeAll { $0.id == conv.id }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateTitle(_ newTitle: String) async {
        guard let conv = conversation else { return }

        do {
            try await NetworkService.shared.updateConversationTitle(id: conv.id, title: newTitle)

            await MainActor.run {
                conversation?.title = newTitle
                if let index = HuggingChatSession.shared.conversations.firstIndex(where: { $0.id == conv.id }) {
                    HuggingChatSession.shared.conversations[index].title = newTitle
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
