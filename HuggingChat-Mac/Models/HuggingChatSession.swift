//
//  HuggingChatSession.swift
//  HuggingChat-Mac
//
//  Created by Cyril Zakka on 8/23/24.
//

import SwiftUI
import Combine
import Foundation
import WebKit
import SafariServices
import AuthenticationServices

@Observable class HuggingChatSession {
    static let shared: HuggingChatSession = HuggingChatSession()

    var clientID: String? {
        didSet {
            if let clientID = clientID {
                KeychainService.shared.save(clientID, for: .clientID)
            }
        }
    }
    var token: String? {
        didSet {
            if let token = token {
                KeychainService.shared.save(token, for: .authToken)
            }
        }
    }
    var conversations: [Conversation] = []
    var availableLLM: [LLMModel] = []
    var currentConversation: String?
    var currentUser: HuggingChatUser?

    private var cancellables: [AnyCancellable] = []

    init() {
        // Session initialization - load stored credentials from Keychain
        self.clientID = KeychainService.shared.retrieve(for: .clientID)
        self.token = KeychainService.shared.retrieve(for: .authToken)

        // Migrate existing cookie-based token to Keychain if present
        migrateTokensFromCookies()
    }
    func refreshLoginState() {
        NetworkService.getCurrentUser()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
            switch completion {
            case .failure(let error):
                AppLogger.error("Failed to refresh login state", error: error, category: .auth)
                self?.currentUser = nil
            case .finished:
                AppLogger.debug("Login state refreshed successfully", category: .auth)
            }
        } receiveValue: { [weak self] user in
            self?.currentUser = user
            AppLogger.info("User logged in: \(user.username)", category: .auth)
        }.store(in: &cancellables)
    }
    
    var hfChatToken: String? {
        // First, try to retrieve from secure Keychain storage
        if let keychainToken = KeychainService.shared.retrieve(for: .hfChatToken) {
            return keychainToken
        }

        // Fallback to cookies for backward compatibility (migration path)
        if let cookieToken = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "hf-chat" })?.value {
            // Migrate to Keychain for future use
            KeychainService.shared.save(cookieToken, for: .hfChatToken)
            return cookieToken
        }

        return nil
    }

    /// Save the hf-chat token securely to Keychain
    func saveHfChatToken(_ token: String) {
        KeychainService.shared.save(token, for: .hfChatToken)
    }

    /// Migrate existing cookie-based tokens to Keychain for enhanced security
    private func migrateTokensFromCookies() {
        // Only migrate if not already in Keychain
        if KeychainService.shared.retrieve(for: .hfChatToken) == nil {
            if let cookieToken = HTTPCookieStorage.shared.cookies?.first(where: { $0.name == "hf-chat" })?.value {
                KeychainService.shared.save(cookieToken, for: .hfChatToken)
            }
        }
    }

    func logout() {
        // Clear all Keychain stored credentials
        KeychainService.shared.deleteAll()

        // Clear cookies for backward compatibility
        let cookieStore = HTTPCookieStorage.shared.cookies
        for cookie in cookieStore ?? [] {
            let backgroundQueue = DispatchQueue(label: "background_queue",
                                                qos: .background)
            backgroundQueue.async {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.clientID = nil
            self?.token = nil
            self?.currentUser = nil
            self?.currentConversation = ""
            DataService.shared.resetLocalModels()
            UserDefaults.standard.setValue(false, forKey: "userLoggedIn")
            UserDefaults.standard.setValue(false, forKey: "onboardingDone")
        }
    }
}
