//
//  KeychainService.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import Foundation
import Security

/// Secure storage service using macOS Keychain for sensitive data like authentication tokens
final class KeychainService {

    static let shared = KeychainService()

    private init() {}

    // MARK: - Service Identifiers

    private let serviceName = "com.huggingface.chat-macOS"

    enum KeychainKey: String {
        case authToken = "auth_token"
        case hfChatToken = "hf_chat_token"
        case clientID = "client_id"
    }

    // MARK: - Public API

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - value: The string to store
    ///   - key: The key identifier
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func save(_ value: String, for key: KeychainKey) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        // Delete any existing item first
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve a string value from the Keychain
    /// - Parameter key: The key identifier
    /// - Returns: The stored string, or nil if not found
    func retrieve(for key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Delete a value from the Keychain
    /// - Parameter key: The key identifier
    /// - Returns: True if successful or item didn't exist, false on error
    @discardableResult
    func delete(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Delete all keychain items for this service
    /// - Returns: True if successful
    @discardableResult
    func deleteAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a key exists in the Keychain
    /// - Parameter key: The key identifier
    /// - Returns: True if the key exists
    func exists(for key: KeychainKey) -> Bool {
        return retrieve(for: key) != nil
    }
}
