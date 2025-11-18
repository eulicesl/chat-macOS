//
//  NetworkService.swift
//  HuggingChat-iOS
//

import Foundation
import Combine

class NetworkService {
    static let shared = NetworkService()

    private let baseURL: String
    private let session: URLSession

    private init() {
        self.baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://huggingface.co"

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    func getLoginURL() async throws -> URL {
        let urlString = "\(baseURL)/chat/login?callback=huggingchat://login/callback"
        guard let url = URL(string: urlString) else {
            throw HFError.invalidURL
        }
        return url
    }

    func validateLogin(code: String, state: String) async throws -> (token: String, user: HuggingChatUser) {
        let urlString = "\(baseURL)/chat/login/callback?code=\(code)&state=\(state)"
        guard let url = URL(string: urlString) else {
            throw HFError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HFError.serverError(httpResponse.statusCode)
        }

        // Extract token from cookies
        guard let cookies = HTTPCookieStorage.shared.cookies(for: url),
              let tokenCookie = cookies.first(where: { $0.name == "hf-chat" }) else {
            throw HFError.unauthorized
        }

        // Get user info
        let user = try await getUser()

        return (tokenCookie.value, user)
    }

    // MARK: - User

    func getUser() async throws -> HuggingChatUser {
        let urlString = "\(baseURL)/chat/api/user"
        return try await makeRequest(urlString: urlString, method: "GET")
    }

    // MARK: - Conversations

    func getConversations() async throws -> [Conversation] {
        let urlString = "\(baseURL)/chat/api/conversations"
        return try await makeRequest(urlString: urlString, method: "GET")
    }

    func getConversation(id: String) async throws -> Conversation {
        let urlString = "\(baseURL)/chat/api/conversation/\(id)"
        return try await makeRequest(urlString: urlString, method: "GET")
    }

    func createConversation(modelId: String) async throws -> Conversation {
        let urlString = "\(baseURL)/chat/conversation"
        let body: [String: Any] = ["model": modelId]
        return try await makeRequest(urlString: urlString, method: "POST", body: body)
    }

    func deleteConversation(id: String) async throws {
        let urlString = "\(baseURL)/chat/conversation/\(id)"
        let _: EmptyResponse = try await makeRequest(urlString: urlString, method: "DELETE")
    }

    func updateConversationTitle(id: String, title: String) async throws {
        let urlString = "\(baseURL)/chat/conversation/\(id)"
        let body: [String: Any] = ["title": title]
        let _: EmptyResponse = try await makeRequest(urlString: urlString, method: "PATCH", body: body)
    }

    // MARK: - Models

    func getModels() async throws -> [LLMModel] {
        let urlString = "\(baseURL)/chat/api/models"
        return try await makeRequest(urlString: urlString, method: "GET")
    }

    // MARK: - Messages

    func streamMessage(conversationId: String, prompt: String, webSearch: Bool = false, files: [String]? = nil) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlString = "\(baseURL)/chat/conversation/\(conversationId)"
                    guard let url = URL(string: urlString) else {
                        throw HFError.invalidURL
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let body: [String: Any] = [
                        "inputs": prompt,
                        "id": UUID().uuidString,
                        "is_retry": false,
                        "is_continue": false,
                        "web_search": webSearch,
                        "files": files ?? []
                    ]

                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw HFError.invalidResponse
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw HFError.serverError(httpResponse.statusCode)
                    }

                    for try await line in bytes.lines {
                        if line.hasPrefix("data:") {
                            let jsonString = String(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
                            continuation.yield(jsonString)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func makeRequest<T: Decodable>(urlString: String, method: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw HFError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HFError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw HFError.unauthorized
            } else if httpResponse.statusCode == 404 {
                throw HFError.notFound
            } else if httpResponse.statusCode == 429 {
                throw HFError.rateLimited
            }
            throw HFError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HFError.decodingError(error)
        }
    }
}

// Empty response for requests that don't return data
private struct EmptyResponse: Decodable {}
