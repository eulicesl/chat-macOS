//
//  KeyboardNetworkService.swift
//  HuggingChat-iOS
//
//  Network service for keyboard AI operations
//

import Foundation

@Observable
final class KeyboardNetworkService: @unchecked Sendable {
    static let shared = KeyboardNetworkService()

    private let networkService = NetworkService.shared
    private let session = HuggingChatSession.shared

    private init() {}

    // MARK: - Translation

    func translate(_ text: String, to targetLanguage: String) async throws -> String {
        // Use the existing NetworkService to perform translation
        let prompt = "Translate the following text to \(targetLanguage):\n\n\(text)"

        // Create a temporary conversation for translation
        let conversation = try await networkService.createConversation(
            modelId: session.availableLLM.first?.id ?? "mistralai/Mistral-7B-Instruct-v0.2"
        )

        // Stream the response and collect it
        var fullResponse = ""
        let stream = networkService.streamMessage(conversationId: conversation.id, prompt: prompt)

        for try await chunk in stream {
            fullResponse += chunk
        }

        return fullResponse.isEmpty ? text : fullResponse
    }

    // MARK: - Writing Improvement

    func improveWriting(_ text: String) async throws -> String {
        let prompt = "Improve the following text, making it clearer and more professional:\n\n\(text)"

        let conversation = try await networkService.createConversation(
            modelId: session.availableLLM.first?.id ?? "mistralai/Mistral-7B-Instruct-v0.2"
        )

        var fullResponse = ""
        let stream = networkService.streamMessage(conversationId: conversation.id, prompt: prompt)

        for try await chunk in stream {
            fullResponse += chunk
        }

        return fullResponse.isEmpty ? text : fullResponse
    }

    // MARK: - Summarization

    func summarize(_ text: String) async throws -> String {
        let prompt = "Summarize the following text concisely:\n\n\(text)"

        let conversation = try await networkService.createConversation(
            modelId: session.availableLLM.first?.id ?? "mistralai/Mistral-7B-Instruct-v0.2"
        )

        var fullResponse = ""
        let stream = networkService.streamMessage(conversationId: conversation.id, prompt: prompt)

        for try await chunk in stream {
            fullResponse += chunk
        }

        return fullResponse.isEmpty ? text : fullResponse
    }
}

// MARK: - Errors

enum KeyboardNetworkError: Error, LocalizedError {
    case notAuthenticated
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in first."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
