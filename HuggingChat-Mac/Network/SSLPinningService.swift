//
//  SSLPinningService.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import Foundation
import Security

/// SSL Certificate Pinning Service for HuggingFace API
/// Prevents MITM attacks by validating server certificates against known public keys
final class SSLPinningService: NSObject {

    static let shared = SSLPinningService()

    private override init() {
        super.init()
    }

    // MARK: - Public Key Hashes

    /// SHA256 hashes of known HuggingFace certificate public keys
    /// These should be updated when HuggingFace rotates their certificates
    /// To get current hash: openssl s_client -connect huggingface.co:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
    ///
    /// ⚠️ SECURITY WARNING: The placeholder hashes below will reject ALL certificates in production!
    /// You MUST replace these with actual HuggingFace certificate hashes before deploying to production.
    /// Failure to do so will result in all network requests being blocked by SSL pinning.
    ///
    /// To disable SSL pinning in development:
    /// - Debug builds: Set UserDefaults key "SSLPinningEnabled" to false
    /// - Release builds: SSL pinning is always enabled (see isEnabled property)
    private let trustedPublicKeyHashes: Set<String> = [
        // HuggingFace primary certificate
        // TODO: REPLACE WITH ACTUAL CERTIFICATE HASH BEFORE PRODUCTION DEPLOYMENT
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",  // ⚠️ PLACEHOLDER - MUST UPDATE

        // Backup certificates for rotation
        // TODO: ADD BACKUP CERTIFICATE HASH FOR CERTIFICATE ROTATION SUPPORT
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=",  // ⚠️ PLACEHOLDER - MUST UPDATE
    ]

    /// Validates that certificate hashes have been updated from placeholders
    /// - Returns: True if using production certificates, false if using placeholders
    private var hasValidCertificates: Bool {
        let placeholders: Set<String> = [
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
            "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
        ]
        return trustedPublicKeyHashes.isDisjoint(with: placeholders)
    }

    /// Domains that require SSL pinning
    private let pinnedDomains: Set<String> = [
        "huggingface.co",
        "cdn-lfs.huggingface.co",
        "cdn-lfs-us-1.huggingface.co"
    ]

    // MARK: - Public API

    /// Validate server trust for SSL pinning
    /// - Parameters:
    ///   - challenge: The authentication challenge
    ///   - completionHandler: Completion handler with disposition and credential
    /// - Returns: True if challenge was handled, false otherwise
    func handleAuthenticationChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) -> Bool {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            return false
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            AppLogger.error("No server trust available for SSL pinning", category: .network)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return true
        }

        let host = challenge.protectionSpace.host

        // Only pin specific domains
        guard pinnedDomains.contains(where: { host.hasSuffix($0) }) else {
            // For non-pinned domains, use default evaluation
            return false
        }

        // Check if SSL pinning is enabled (allows disabling in debug builds)
        guard isEnabled else {
            AppLogger.debug("SSL pinning disabled for \(host) - using default validation", category: .network)
            // Use default system validation when pinning is disabled
            return false
        }

        // Warn if using placeholder certificates
        if !hasValidCertificates {
            AppLogger.warning("⚠️ SSL Pinning is using PLACEHOLDER certificates - update before production!", category: .network)
        }

        // Validate the certificate
        if validateServerTrust(serverTrust, forHost: host) {
            AppLogger.debug("SSL pinning validation succeeded for \(host)", category: .network)
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            AppLogger.error("SSL pinning validation failed for \(host) - Potential MITM attack", category: .network)
            completionHandler(.cancelAuthenticationChallenge, nil)
        }

        return true
    }

    // MARK: - Private Methods

    /// Validate server trust against pinned public keys
    /// - Parameters:
    ///   - serverTrust: The server trust to validate
    ///   - host: The host being validated
    /// - Returns: True if validation succeeds
    private func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {

        // Set SSL policy for the host
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)

        // Evaluate the trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            if let error = error {
                AppLogger.error("Server trust evaluation failed", error: error as Error, category: .network)
            }
            return false
        }

        // Extract public keys from the certificate chain
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            AppLogger.error("Failed to extract certificate chain", category: .network)
            return false
        }

        // Check if any certificate in the chain matches our pinned keys
        for certificate in certificateChain {
            if let publicKeyHash = extractPublicKeyHash(from: certificate) {
                if trustedPublicKeyHashes.contains(publicKeyHash) {
                    return true
                }
            }
        }

        AppLogger.warning("No matching pinned public key found in certificate chain for \(host)", category: .network)
        return false
    }

    /// Extract SHA256 hash of public key from certificate
    /// - Parameter certificate: The certificate to extract from
    /// - Returns: Base64-encoded SHA256 hash of the public key, or nil on failure
    private func extractPublicKeyHash(from certificate: SecCertificate) -> String? {

        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // Compute SHA256 hash
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        // Convert to base64
        let hashData = Data(hash)
        return hashData.base64EncodedString()
    }

    /// Enable SSL pinning for development/testing
    /// In development, you might want to disable pinning or use different certificates
    var isEnabled: Bool {
        #if DEBUG
        // In debug builds, check for an environment variable or user default
        return UserDefaults.standard.bool(forKey: "SSLPinningEnabled")
        #else
        // Always enabled in release builds
        return true
        #endif
    }
}

// MARK: - CommonCrypto Bridge

import CommonCrypto

// Note: CC_SHA256 is imported from CommonCrypto
// CC_SHA256_DIGEST_LENGTH is 32 bytes
