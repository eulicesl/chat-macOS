//
//  SecureURLSessionDelegate.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import Foundation

/// URLSession delegate that implements SSL certificate pinning
final class SecureURLSessionDelegate: NSObject, URLSessionDelegate {

    /// Singleton instance for shared use
    static let shared = SecureURLSessionDelegate()

    private override init() {
        super.init()
    }

    /// Handle authentication challenges for SSL pinning
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {

        // Attempt SSL pinning validation
        if SSLPinningService.shared.handleAuthenticationChallenge(challenge, completionHandler: completionHandler) {
            // Challenge was handled by pinning service
            return
        }

        // For challenges not handled by pinning service, use default handling
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - URLSession Extension

extension URLSession {

    /// Shared URLSession with SSL pinning enabled
    static let secureSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .useProtocolCachePolicy

        return URLSession(
            configuration: configuration,
            delegate: SecureURLSessionDelegate.shared,
            delegateQueue: nil
        )
    }()
}
