//
//  HuggingChatSession.swift
//  HuggingChat-iOS
//

import Foundation
import Observation

@Observable
final class HuggingChatSession: @unchecked Sendable {
    static let shared = HuggingChatSession()

    var currentUser: HuggingChatUser?
    var token: String?
    var conversations: [Conversation] = []
    var availableLLM: [LLMModel] = []
    var isLoading = false
    var errorMessage: String?

    private init() {
        loadSession()
    }

    func loadSession() {
        // Load token from UserDefaults
        if let savedToken = UserDefaults.standard.string(forKey: "hf-chat-token") {
            self.token = savedToken
        }

        // Load user from UserDefaults
        if let userData = UserDefaults.standard.data(forKey: "hf-chat-user"),
           let user = try? JSONDecoder().decode(HuggingChatUser.self, from: userData) {
            self.currentUser = user
        }
    }

    func saveSession() {
        // Save token
        if let token = token {
            UserDefaults.standard.set(token, forKey: "hf-chat-token")
        } else {
            UserDefaults.standard.removeObject(forKey: "hf-chat-token")
        }

        // Save user
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "hf-chat-user")
        } else {
            UserDefaults.standard.removeObject(forKey: "hf-chat-user")
        }
    }

    func signOut() {
        currentUser = nil
        token = nil
        conversations = []
        availableLLM = []
        UserDefaults.standard.removeObject(forKey: "hf-chat-token")
        UserDefaults.standard.removeObject(forKey: "hf-chat-user")
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    func setToken(_ token: String) {
        self.token = token
        saveSession()
    }

    func setUser(_ user: HuggingChatUser) {
        self.currentUser = user
        saveSession()
    }
}
