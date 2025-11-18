//
//  CoordinatorModel.swift
//  HuggingChat-iOS
//

import Foundation
import AuthenticationServices
import Observation

@Observable
class CoordinatorModel: NSObject {
    var isAuthenticating = false
    var errorMessage: String?

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

            let session = ASWebAuthenticationSession(url: loginURL, callbackURLScheme: callbackURLScheme) { callbackURL, error in
                Task {
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError {
                            if authError.code == .canceledLogin {
                                // User cancelled, don't show error
                                return
                            }
                        }
                        await MainActor.run {
                            self.errorMessage = "Authentication failed: \(error.localizedDescription)"
                        }
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        await MainActor.run {
                            self.errorMessage = "No callback URL received"
                        }
                        return
                    }

                    // Parse callback URL
                    await self.handleCallback(url: callbackURL)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            await MainActor.run {
                session.start()
            }

        } catch {
            errorMessage = "Failed to start authentication: \(error.localizedDescription)"
            throw error
        }
    }

    private func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            await MainActor.run {
                errorMessage = "Invalid callback URL"
            }
            return
        }

        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let state = queryItems.first(where: { $0.name == "state" })?.value else {
            await MainActor.run {
                errorMessage = "Missing code or state in callback"
            }
            return
        }

        do {
            let (token, user) = try await NetworkService.shared.validateLogin(code: code, state: state)

            await MainActor.run {
                HuggingChatSession.shared.setToken(token)
                HuggingChatSession.shared.setUser(user)
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to validate login: \(error.localizedDescription)"
            }
        }
    }
}

extension CoordinatorModel: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
