//
//  AppIntents.swift
//  HuggingChat-iOS
//
//  App Intents for Siri and Shortcuts integration
//

import AppIntents
import Foundation

// MARK: - App Shortcuts Provider

struct HuggingChatShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartNewChatIntent(),
            phrases: [
                "Start a new chat in \(.applicationName)",
                "Begin a conversation in \(.applicationName)",
                "New chat with \(.applicationName)"
            ],
            shortTitle: "New Chat",
            systemImageName: "message.badge.plus"
        )

        AppShortcut(
            intent: AskQuestionIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Send a question to \(.applicationName)",
                "Chat with \(.applicationName)"
            ],
            shortTitle: "Ask Question",
            systemImageName: "bubble.left.and.bubble.right"
        )

        AppShortcut(
            intent: GetRecentConversationsIntent(),
            phrases: [
                "Show my recent chats in \(.applicationName)",
                "Open recent conversations in \(.applicationName)"
            ],
            shortTitle: "Recent Chats",
            systemImageName: "clock"
        )
    }
}

// MARK: - Start New Chat Intent

struct StartNewChatIntent: AppIntent {
    static let title: LocalizedStringResource = "Start New Chat"
    static let description = IntentDescription("Start a new conversation in HuggingChat")

    @Parameter(title: "Model")
    var model: String?

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        // Create new conversation
        let session = HuggingChatSession.shared
        guard let firstModel = session.availableLLM.first else {
            throw HCIntentError.message("No models available")
        }

        let selectedModelId = model ?? firstModel.id
        var openIntent = OpenConversationIntent()
        openIntent.modelId = selectedModelId

        return .result(opensIntent: openIntent)
    }
}

// MARK: - Ask Question Intent

struct AskQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Question"
    static let description = IntentDescription("Ask a question to HuggingChat")

    @Parameter(title: "Question", requestValueDialog: "What would you like to ask?")
    var question: String

    @Parameter(title: "Use Web Search", default: false)
    var useWebSearch: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let session = HuggingChatSession.shared

        guard session.token != nil else {
            throw HCIntentError.message("Please sign in to HuggingChat first")
        }

        // Get or create conversation
        let viewModel = ConversationViewModel()

        if let firstConversation = session.conversations.first {
            await viewModel.loadConversation(firstConversation)
        } else {
            // Create new conversation
            guard let firstModel = session.availableLLM.first else {
                throw HCIntentError.message("No models available")
            }
            await viewModel.createNewConversation(modelId: firstModel.id)
        }

        // Send message
        viewModel.useWebSearch = useWebSearch
        await viewModel.sendMessage(question)

        // Wait for response (with timeout)
        var waitTime = 0.0
        while viewModel.isInteracting && waitTime < 30.0 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            waitTime += 0.5
        }

        let response = viewModel.messages.last?.content ?? "No response received"

        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}

// MARK: - Get Recent Conversations Intent

struct GetRecentConversationsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Recent Conversations"
    static let description = IntentDescription("Get your recent conversations from HuggingChat")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ConversationEntity]> {
        let session = HuggingChatSession.shared

        guard session.token != nil else {
            throw HCIntentError.message("Please sign in to HuggingChat first")
        }

        let menuViewModel = MenuViewModel()
        await menuViewModel.getConversations()

        let entities = session.conversations.prefix(5).map { conversation in
            ConversationEntity(
                id: conversation.id,
                title: conversation.title,
                updatedAt: conversation.updatedAt
            )
        }

        return .result(value: entities)
    }
}

// MARK: - Open Conversation Intent

struct OpenConversationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Conversation"
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Model ID")
    var modelId: String

    @MainActor
    func perform() async throws -> some IntentResult {
        // This will open the app
        return .result()
    }
}

// MARK: - Conversation Entity

struct ConversationEntity: AppEntity {
    let id: String
    let title: String
    let updatedAt: Date

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Conversation"
    static let defaultQuery = ConversationEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(updatedAt.timeAgo())"
        )
    }
}

struct ConversationEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ConversationEntity] {
        let session = HuggingChatSession.shared
        return session.conversations
            .filter { identifiers.contains($0.id) }
            .map { conversation in
                ConversationEntity(
                    id: conversation.id,
                    title: conversation.title,
                    updatedAt: conversation.updatedAt
                )
            }
    }

    @MainActor
    func suggestedEntities() async throws -> [ConversationEntity] {
        let session = HuggingChatSession.shared
        return session.conversations.prefix(5).map { conversation in
            ConversationEntity(
                id: conversation.id,
                title: conversation.title,
                updatedAt: conversation.updatedAt
            )
        }
    }
}

// MARK: - Intent Error

enum HCIntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let message):
            return LocalizedStringResource(stringLiteral: message)
        }
    }
}
