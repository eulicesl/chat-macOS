//
//  KeyboardNetworkService.swift
//  HuggingChatKeyboard
//
//  Network service for keyboard extension
//

import Foundation

/// Network service for handling AI requests from keyboard
class KeyboardNetworkService {
    static let shared = KeyboardNetworkService()

    private let baseURL = "https://huggingface.co"
    private let sharedData = SharedDataManager.shared

    private init() {}

    // MARK: - AI Completion

    /// Sends a quick AI request and returns the response
    func getCompletion(prompt: String, modelId: String? = nil) async throws -> String {
        // Check if network access is allowed
        guard sharedData.allowNetworkAccess else {
            throw KeyboardNetworkError.networkAccessDisabled
        }

        // Get session token
        guard let token = sharedData.getSessionToken(), !token.isEmpty else {
            throw KeyboardNetworkError.notAuthenticated
        }

        // Use selected model or default
        let model = modelId ?? sharedData.selectedModelId

        // For keyboard, we'll use a simpler streaming approach
        // Create a temporary conversation and get response
        let conversationId = try await createTemporaryConversation(modelId: model)

        // Send message and get response
        let response = try await sendMessage(
            conversationId: conversationId,
            prompt: prompt,
            token: token
        )

        // Clean up temporary conversation (optional - could keep for context)
        // try? await deleteConversation(conversationId: conversationId, token: token)

        return response
    }

    // MARK: - Conversation Management

    private func createTemporaryConversation(modelId: String) async throws -> String {
        guard let token = sharedData.getSessionToken() else {
            throw KeyboardNetworkError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/chat/conversation")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hf-chat=\(token)", forHTTPHeaderField: "Cookie")

        let body: [String: Any] = [
            "model": modelId,
            "preprompt": ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw KeyboardNetworkError.requestFailed
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let conversationId = json["conversationId"] as? String {
            return conversationId
        }

        throw KeyboardNetworkError.invalidResponse
    }

    private func sendMessage(conversationId: String, prompt: String, token: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/conversation/\(conversationId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hf-chat=\(token)", forHTTPHeaderField: "Cookie")

        let body: [String: Any] = [
            "inputs": prompt,
            "id": UUID().uuidString,
            "is_retry": false,
            "is_continue": false,
            "web_search": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // For keyboard, we'll use a simpler non-streaming approach
        // In production, you might want to implement SSE streaming
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw KeyboardNetworkError.requestFailed
        }

        // Parse the response - HuggingChat returns SSE events
        // For simplicity, we'll extract the final text from the events
        let responseText = String(data: data, encoding: .utf8) ?? ""
        let extractedText = extractTextFromSSE(responseText)

        return extractedText.isEmpty ? "Unable to generate response" : extractedText
    }

    private func extractTextFromSSE(_ sseData: String) -> String {
        // Parse SSE format: data: {...}\n\n
        var fullText = ""

        let lines = sseData.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("data:") {
                let jsonString = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    fullText += token
                }
            }
        }

        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Translation

    /// Translates text using AI
    func translate(_ text: String, to language: String = "English") async throws -> String {
        let prompt = "Translate the following text to \(language). Only provide the translation, nothing else:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Improves writing
    func improveWriting(_ text: String) async throws -> String {
        let prompt = "Improve this text to be more professional and clear. Only provide the improved version:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Fixes grammar
    func fixGrammar(_ text: String) async throws -> String {
        let prompt = "Fix any grammar and spelling errors in this text. Only provide the corrected version:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Summarizes text
    func summarize(_ text: String) async throws -> String {
        let prompt = "Summarize this text in 2-3 sentences:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Makes text more formal
    func makeFormal(_ text: String) async throws -> String {
        let prompt = "Rewrite this text to be more formal and professional. Only provide the rewritten version:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Makes text more casual
    func makeCasual(_ text: String) async throws -> String {
        let prompt = "Rewrite this text to be more casual and friendly. Only provide the rewritten version:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }

    /// Explains text simply
    func explain(_ text: String) async throws -> String {
        let prompt = "Explain this in simple terms:\n\n\(text)"
        return try await getCompletion(prompt: prompt)
    }
}

// MARK: - Errors

enum KeyboardNetworkError: Error, LocalizedError {
    case networkAccessDisabled
    case notAuthenticated
    case requestFailed
    case invalidResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .networkAccessDisabled:
            return "Network access is disabled. Enable it in HuggingChat settings."
        case .notAuthenticated:
            return "Not logged in. Please sign in using the HuggingChat app."
        case .requestFailed:
            return "Request failed. Please try again."
        case .invalidResponse:
            return "Invalid response from server."
        case .timeout:
            return "Request timed out. Please try again."
        }
    }
}
