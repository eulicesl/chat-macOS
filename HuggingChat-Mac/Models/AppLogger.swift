//
//  AppLogger.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import Foundation
import OSLog

/// Centralized logging service using Apple's unified logging system (os_log)
/// Replaces debug print statements with structured, filterable logs
final class AppLogger {

    static let shared = AppLogger()

    private init() {}

    // MARK: - Log Categories

    /// Network-related operations (API calls, responses, errors)
    static let network = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "Network")

    /// Authentication and session management
    static let auth = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "Authentication")

    /// Audio transcription and voice mode
    static let audio = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "Audio")

    /// Local LLM model management
    static let model = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "Model")

    /// Conversation and message handling
    static let conversation = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "Conversation")

    /// UI events and interactions
    static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "UI")

    /// General app lifecycle and system events
    static let general = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "General")

    /// File operations and data persistence
    static let file = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS", category: "File")

    // MARK: - Convenience Methods

    /// Log an informational message
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category (default: general)
    static func info(_ message: String, category: Logger = general) {
        category.info("\(message, privacy: .public)")
    }

    /// Log a debug message (only visible in debug builds)
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category (default: general)
    static func debug(_ message: String, category: Logger = general) {
        category.debug("\(message, privacy: .public)")
    }

    /// Log a warning
    /// - Parameters:
    ///   - message: The message to log
    ///   - category: The logger category (default: general)
    static func warning(_ message: String, category: Logger = general) {
        category.warning("\(message, privacy: .public)")
    }

    /// Log an error
    /// - Parameters:
    ///   - message: The error message
    ///   - error: Optional Error object for additional context
    ///   - category: The logger category (default: general)
    static func error(_ message: String, error: Error? = nil, category: Logger = general) {
        if let error = error {
            category.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            category.error("\(message, privacy: .public)")
        }
    }

    /// Log a critical error that requires immediate attention
    /// - Parameters:
    ///   - message: The critical error message
    ///   - error: Optional Error object for additional context
    ///   - category: The logger category (default: general)
    static func critical(_ message: String, error: Error? = nil, category: Logger = general) {
        if let error = error {
            category.critical("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            category.critical("\(message, privacy: .public)")
        }
    }

    /// Log a network request
    /// - Parameters:
    ///   - endpoint: The endpoint being called
    ///   - method: HTTP method (GET, POST, etc.)
    static func logNetworkRequest(endpoint: String, method: String = "GET") {
        network.info("[\(method, privacy: .public)] \(endpoint, privacy: .public)")
    }

    /// Log a network response
    /// - Parameters:
    ///   - endpoint: The endpoint that responded
    ///   - statusCode: HTTP status code
    static func logNetworkResponse(endpoint: String, statusCode: Int) {
        if statusCode >= 200 && statusCode < 300 {
            network.info("[\(statusCode, privacy: .public)] Success: \(endpoint, privacy: .public)")
        } else {
            network.error("[\(statusCode, privacy: .public)] Error: \(endpoint, privacy: .public)")
        }
    }

    /// Log authentication events
    /// - Parameters:
    ///   - event: Description of the auth event
    ///   - success: Whether the event was successful
    static func logAuth(event: String, success: Bool) {
        if success {
            auth.info("\(event, privacy: .public) - Success")
        } else {
            auth.error("\(event, privacy: .public) - Failed")
        }
    }
}

// MARK: - Usage Examples

/*
 // Instead of:
 print("User logged in")

 // Use:
 AppLogger.info("User logged in successfully", category: .auth)

 // Instead of:
 print("Error loading conversation: \(error.localizedDescription)")

 // Use:
 AppLogger.error("Failed to load conversation", error: error, category: .conversation)

 // Instead of:
 print(error.localizedDescription)

 // Use:
 AppLogger.error("An error occurred", error: error)

 // For network requests:
 AppLogger.logNetworkRequest(endpoint: "/chat/conversation", method: "POST")
 AppLogger.logNetworkResponse(endpoint: "/chat/conversation", statusCode: 200)

 // View logs in Console.app by filtering for subsystem: com.huggingface.chat-macOS
 */
