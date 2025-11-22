//
//  CoordinatorModel.swift
//  HuggingChat-iOS
//

import Foundation
import AuthenticationServices
import Observation

@MainActor
@Observable
class CoordinatorModel: NSObject {
    var isAuthenticating = false
    var errorMessage: String?

    // Store authentication session as property to prevent premature deallocation
    private var authenticationSession: ASWebAuthenticationSession?

    func signIn(presentationContext: ASPresentationAnchor) async throws {
        isAuthenticating = true
        errorMessage = nil

        defer {
            isAuthenticating = false
        }

        do {
            // Get login URL
            let loginURL = try await NetworkService.shared.getLoginURL()

            // Start web authentication session
            let callbackURLScheme = "huggingchat"

            authenticationSession = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: callbackURLScheme) { [weak self] callbackURL, error in
                guard let self else { return }

                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                        // User cancelled, don't show error
                        Task { @MainActor in
                            self.authenticationSession = nil
                        }
                        return
                    }
                    self.setError("Authentication failed: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.authenticationSession = nil
                    }
                    return
                }

                guard let callbackURL = callbackURL else {
                    self.setError("No callback URL received")
                    Task { @MainActor in
                        self.authenticationSession = nil
                    }
                    return
                }

                Task { @MainActor in
                    await self.handleCallback(url: callbackURL)
                    self.authenticationSession = nil
                }
            }

            authenticationSession?.presentationContextProvider = self
            authenticationSession?.prefersEphemeralWebBrowserSession = false

            authenticationSession?.start()

        } catch {
            errorMessage = "Failed to start authentication: \(error.localizedDescription)"
            throw error
        }
    }

    private func setError(_ message: String) {
        self.errorMessage = message
    }

    @MainActor
    private func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            errorMessage = "Invalid callback URL"
            return
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value else {
            errorMessage = "Missing code or state in callback"
            return
        }

        do {
            let (token, user) = try await NetworkService.shared.validateLogin(code: code, state: state)

            HuggingChatSession.shared.setToken(token)
            HuggingChatSession.shared.setUser(user)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } catch {
            self.errorMessage = "Failed to validate login: \(error.localizedDescription)"
        }
    }
}

extension CoordinatorModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
