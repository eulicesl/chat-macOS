//
//  CrashReporter.swift
//  HuggingChat-Mac
//
//  Created by Claude Code on production readiness improvements
//

import Foundation
import AppKit

/// Crash reporting and error tracking service
/// Provides foundation for integrating with services like Sentry, Crashlytics, or custom backends
final class CrashReporter {

    static let shared = CrashReporter()

    private var isInitialized = false
    private var crashHandlers: [CrashHandler] = []

    // MARK: - Configuration

    struct Configuration {
        /// Enable/disable crash reporting
        var isEnabled: Bool = true

        /// Environment (development, staging, production)
        var environment: String = "production"

        /// App version for crash reports
        var appVersion: String = UserAgentBuilder.appVersion

        /// Build number for crash reports
        var buildNumber: String = UserAgentBuilder.buildNumber

        /// User ID (optional, for user-scoped crash tracking)
        var userID: String?

        /// Additional metadata to attach to all crash reports
        var metadata: [String: Any] = [:]

        /// Whether to send crash reports in debug builds
        var sendInDebug: Bool = false
    }

    private var configuration = Configuration()

    private init() {}

    // MARK: - Initialization

    /// Initialize the crash reporter with configuration
    /// - Parameter config: Configuration for crash reporting
    func initialize(with config: Configuration = Configuration()) {
        guard !isInitialized else {
            AppLogger.warning("CrashReporter already initialized", category: .general)
            return
        }

        self.configuration = config

        #if DEBUG
        guard config.sendInDebug else {
            AppLogger.info("Crash reporting disabled in debug builds", category: .general)
            return
        }
        #endif

        guard config.isEnabled else {
            AppLogger.info("Crash reporting disabled by configuration", category: .general)
            return
        }

        setupCrashHandlers()
        setupExceptionHandler()

        isInitialized = true
        AppLogger.info("CrashReporter initialized for environment: \(config.environment)", category: .general)
    }

    // MARK: - Public API

    /// Record a non-fatal error
    /// - Parameters:
    ///   - error: The error to report
    ///   - context: Additional context about the error
    func recordError(_ error: Error, context: [String: Any] = [:]) {
        guard isInitialized, configuration.isEnabled else { return }

        let errorReport = ErrorReport(
            error: error,
            context: context,
            configuration: configuration
        )

        AppLogger.error("Recorded error: \(error.localizedDescription)", category: .general)

        // Send to crash handlers
        crashHandlers.forEach { $0.handleError(errorReport) }

        // In production, send to crash reporting service
        sendErrorReport(errorReport)
    }

    /// Record a custom message/event
    /// - Parameters:
    ///   - message: The message to record
    ///   - level: Severity level
    ///   - context: Additional context
    func recordMessage(_ message: String, level: ErrorLevel = .info, context: [String: Any] = [:]) {
        guard isInitialized, configuration.isEnabled else { return }

        let messageReport = MessageReport(
            message: message,
            level: level,
            context: context,
            configuration: configuration
        )

        switch level {
        case .debug:
            AppLogger.debug(message, category: .general)
        case .info:
            AppLogger.info(message, category: .general)
        case .warning:
            AppLogger.warning(message, category: .general)
        case .error:
            AppLogger.error(message, category: .general)
        case .fatal:
            AppLogger.critical(message, category: .general)
        }

        // Send to crash handlers
        crashHandlers.forEach { $0.handleMessage(messageReport) }
    }

    /// Set user context for crash reports
    /// - Parameters:
    ///   - userID: User identifier
    ///   - email: User email (optional)
    ///   - username: Username (optional)
    func setUser(userID: String?, email: String? = nil, username: String? = nil) {
        configuration.userID = userID

        var userContext: [String: Any] = [:]
        if let userID = userID { userContext["id"] = userID }
        if let email = email { userContext["email"] = email }
        if let username = username { userContext["username"] = username }

        configuration.metadata["user"] = userContext
        AppLogger.info("Updated crash reporter user context", category: .general)
    }

    /// Add custom metadata to all crash reports
    /// - Parameter metadata: Key-value pairs to add
    func addMetadata(_ metadata: [String: Any]) {
        configuration.metadata.merge(metadata) { _, new in new }
    }

    /// Register a custom crash handler
    /// - Parameter handler: The crash handler to register
    func registerHandler(_ handler: CrashHandler) {
        crashHandlers.append(handler)
        AppLogger.info("Registered crash handler: \(type(of: handler))", category: .general)
    }

    // MARK: - Private Methods

    private func setupCrashHandlers() {
        // Register default file-based handler for local crash logs
        let fileHandler = FileCrashHandler()
        registerHandler(fileHandler)

        // In production, register handlers for crash reporting services
        // Example: registerHandler(SentryCrashHandler())
    }

    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleUncaughtException(exception)
        }

        // Set up signal handlers for crashes
        signal(SIGABRT, signalHandler)
        signal(SIGILL, signalHandler)
        signal(SIGSEGV, signalHandler)
        signal(SIGFPE, signalHandler)
        signal(SIGBUS, signalHandler)
        signal(SIGPIPE, signalHandler)
    }

    private func handleUncaughtException(_ exception: NSException) {
        let errorInfo: [String: Any] = [
            "exception_name": exception.name.rawValue,
            "exception_reason": exception.reason ?? "No reason provided",
            "call_stack": exception.callStackSymbols
        ]

        AppLogger.critical("Uncaught exception: \(exception.name.rawValue)", category: .general)

        let crashReport = CrashReport(
            type: .exception,
            name: exception.name.rawValue,
            reason: exception.reason ?? "",
            stackTrace: exception.callStackSymbols,
            context: errorInfo,
            configuration: configuration
        )

        crashHandlers.forEach { $0.handleCrash(crashReport) }
    }

    private func sendErrorReport(_ report: ErrorReport) {
        // In production, send to crash reporting backend
        // Example: POST to crash reporting API
        #if DEBUG
        // In debug, just log
        AppLogger.debug("Would send error report: \(report.error.localizedDescription)", category: .general)
        #endif
    }
}

// MARK: - Signal Handler

private func signalHandler(signal: Int32) {
    let signalName: String
    switch signal {
    case SIGABRT: signalName = "SIGABRT"
    case SIGILL: signalName = "SIGILL"
    case SIGSEGV: signalName = "SIGSEGV"
    case SIGFPE: signalName = "SIGFPE"
    case SIGBUS: signalName = "SIGBUS"
    case SIGPIPE: signalName = "SIGPIPE"
    default: signalName = "Unknown signal \(signal)"
    }

    AppLogger.critical("Received signal: \(signalName)", category: .general)

    let crashReport = CrashReport(
        type: .signal,
        name: signalName,
        reason: "Application received signal \(signal)",
        stackTrace: Thread.callStackSymbols,
        context: ["signal_code": signal],
        configuration: CrashReporter.shared.configuration
    )

    CrashReporter.shared.crashHandlers.forEach { $0.handleCrash(crashReport) }

    // Re-raise signal for system handling
    signal(signal, SIG_DFL)
    raise(signal)
}

// MARK: - Supporting Types

enum ErrorLevel: String {
    case debug
    case info
    case warning
    case error
    case fatal
}

struct ErrorReport {
    let error: Error
    let context: [String: Any]
    let configuration: CrashReporter.Configuration
    let timestamp: Date = Date()
}

struct MessageReport {
    let message: String
    let level: ErrorLevel
    let context: [String: Any]
    let configuration: CrashReporter.Configuration
    let timestamp: Date = Date()
}

struct CrashReport {
    enum CrashType {
        case exception
        case signal
    }

    let type: CrashType
    let name: String
    let reason: String
    let stackTrace: [String]
    let context: [String: Any]
    let configuration: CrashReporter.Configuration
    let timestamp: Date = Date()
}

protocol CrashHandler {
    func handleCrash(_ report: CrashReport)
    func handleError(_ report: ErrorReport)
    func handleMessage(_ report: MessageReport)
}

// MARK: - File-Based Crash Handler

class FileCrashHandler: CrashHandler {

    private let crashLogDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.huggingface.chat-macOS"
        let crashDir = appSupport.appendingPathComponent(bundleID).appendingPathComponent("CrashLogs")

        try? FileManager.default.createDirectory(at: crashDir, withIntermediateDirectories: true)

        return crashDir
    }()

    func handleCrash(_ report: CrashReport) {
        let filename = "crash-\(report.timestamp.timeIntervalSince1970).log"
        let fileURL = crashLogDirectory.appendingPathComponent(filename)

        var logContent = """
        CRASH REPORT
        ============
        Type: \(report.type)
        Name: \(report.name)
        Reason: \(report.reason)
        Timestamp: \(report.timestamp)
        App Version: \(report.configuration.appVersion)
        Build: \(report.configuration.buildNumber)
        Environment: \(report.configuration.environment)

        Stack Trace:
        \(report.stackTrace.joined(separator: "\n"))

        """

        try? logContent.write(to: fileURL, atomically: true, encoding: .utf8)
        AppLogger.info("Crash log saved to: \(fileURL.path)", category: .general)
    }

    func handleError(_ report: ErrorReport) {
        let filename = "error-\(report.timestamp.timeIntervalSince1970).log"
        let fileURL = crashLogDirectory.appendingPathComponent(filename)

        let logContent = """
        ERROR REPORT
        ============
        Error: \(report.error.localizedDescription)
        Timestamp: \(report.timestamp)
        App Version: \(report.configuration.appVersion)

        Context:
        \(report.context)
        """

        try? logContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func handleMessage(_ report: MessageReport) {
        // Only write warnings and above to disk
        guard report.level != .debug && report.level != .info else { return }

        let filename = "message-\(report.timestamp.timeIntervalSince1970).log"
        let fileURL = crashLogDirectory.appendingPathComponent(filename)

        let logContent = """
        MESSAGE REPORT
        ==============
        Level: \(report.level.rawValue)
        Message: \(report.message)
        Timestamp: \(report.timestamp)
        """

        try? logContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
