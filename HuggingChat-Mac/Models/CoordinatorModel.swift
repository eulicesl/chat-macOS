//
//  CoordinatorModel.swift
//  HuggingChat-Mac
//
//  Created by Cyril Zakka on 8/24/24.
//

import SwiftUI
import Combine

@Observable class CoordinatorModel {

    var authURL: URL?
    var showWebAuth = false
    var errorMessage: String?
    var showError = false

    private var cancellables = Set<AnyCancellable>()

    func signin() {
        NetworkService.loginChat()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
            switch completion {
            case .failure(let error):
                self?.errorMessage = "Sign in failed: \(error.localizedDescription)"
                self?.showError = true
            case .finished: break
            }
        } receiveValue: { [weak self] loginChat in
            guard let url = self?.generateURL(from: loginChat.location) else { return }
            // Use secure in-app WebView for OAuth instead of system browser
            self?.authURL = url
            self?.showWebAuth = true
        }.store(in: &cancellables)
    }
    
    func appleSignin(token: String) {
        NetworkService.loginChat()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
            switch completion {
            case .failure(let error):
                self?.errorMessage = "Apple Sign in failed: \(error.localizedDescription)"
                self?.showError = true
            case .finished: break
            }
        } receiveValue: { [weak self] loginChat in
            guard let url = self?.generateURL(from: loginChat.location, appleToken: token) else { return }
            // Use secure in-app WebView for OAuth
            self?.authURL = url
            self?.showWebAuth = true
        }.store(in: &cancellables)
    }
    
    func validateSignup(code: String, state: String) {
        NetworkService.validateSignIn(code: code, state: state)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
            switch completion {
            case .finished:
                // Successfully validated
                break
            case .failure(let error):
                self?.errorMessage = "Could not validate sign in: \(error.localizedDescription)"
                self?.showError = true
            }
        } receiveValue: { _ in
            HuggingChatSession.shared.refreshLoginState()
            UserDefaults.standard.set(true, forKey: "userLoggedIn")
        }.store(in: &cancellables)
    }
    
    private func generateURL(from location: String, appleToken: String? = nil) -> URL? {
        var s_url = location
        if appleToken != nil {
            s_url = location.replacingOccurrences(of: "/oauth/authorize", with: "/login/apple")
        }
        guard var component = URLComponents(string: s_url) else { return nil }
        var queryItems = component.queryItems ?? []
        queryItems.append(URLQueryItem(name: "prompt", value: "login"))
        if let appleToken = appleToken {
            queryItems.append(URLQueryItem(name: "id_token", value: appleToken))
        }
        component.queryItems = queryItems

        return component.url
    }
}
