//
//  SharedDataManager.swift
//  HuggingChat
//
//  Manages shared data between main app and keyboard extension via App Groups
//

import Foundation
import Observation

/// Shared data manager for communication between main app and keyboard extension
/// Uses App Groups (group.com.huggingface.huggingchat) for data sharing
@Observable
final class SharedDataManager: @unchecked Sendable {
    static let shared = SharedDataManager()

    // App Group identifier - must match in both app and extension entitlements
    private let appGroupIdentifier = "group.com.huggingface.huggingchat"

    // UserDefaults suite for shared preferences
    private var sharedDefaults: UserDefaults?

    // Keys for shared data
    private enum Keys {
        static let isKeyboardEnabled = "isKeyboardEnabled"
        static let allowNetworkAccess = "allowNetworkAccess"
        static let selectedModelId = "selectedModelId"
        static let enableVoiceInput = "enableVoiceInput"
        static let enableSmartSuggestions = "enableSmartSuggestions"
        static let quickCommands = "quickCommands"
        static let keyboardTheme = "keyboardTheme"
        static let sessionToken = "sessionToken"
        static let conversationHistory = "conversationHistory"
        static let recentCompletions = "recentCompletions"
        static let clipboardContext = "clipboardContext"
    }

    // MARK: - Properties

    var isKeyboardEnabled: Bool {
        get { sharedDefaults?.bool(forKey: Keys.isKeyboardEnabled) ?? false }
        set { sharedDefaults?.set(newValue, forKey: Keys.isKeyboardEnabled) }
    }

    var allowNetworkAccess: Bool {
        get { sharedDefaults?.bool(forKey: Keys.allowNetworkAccess) ?? true }
        set { sharedDefaults?.set(newValue, forKey: Keys.allowNetworkAccess) }
    }

    var selectedModelId: String {
        get { sharedDefaults?.string(forKey: Keys.selectedModelId) ?? "" }
        set { sharedDefaults?.set(newValue, forKey: Keys.selectedModelId) }
    }

    var enableVoiceInput: Bool {
        get { sharedDefaults?.bool(forKey: Keys.enableVoiceInput) ?? true }
        set { sharedDefaults?.set(newValue, forKey: Keys.enableVoiceInput) }
    }

    var enableSmartSuggestions: Bool {
        get { sharedDefaults?.bool(forKey: Keys.enableSmartSuggestions) ?? true }
        set { sharedDefaults?.set(newValue, forKey: Keys.enableSmartSuggestions) }
    }

    var keyboardTheme: KeyboardTheme {
        get {
            guard let rawValue = sharedDefaults?.string(forKey: Keys.keyboardTheme),
                  let theme = KeyboardTheme(rawValue: rawValue) else {
                return .auto
            }
            return theme
        }
        set { sharedDefaults?.set(newValue.rawValue, forKey: Keys.keyboardTheme) }
    }

    // MARK: - Initialization

    private init() {
        sharedDefaults = UserDefaults(suiteName: appGroupIdentifier)

        if sharedDefaults == nil {
            print("⚠️ Failed to create shared UserDefaults with App Group: \(appGroupIdentifier)")
            print("⚠️ Make sure App Groups are configured in Xcode project settings")
        }
    }

    // MARK: - Session Management

    func saveSessionToken(_ token: String) {
        sharedDefaults?.set(token, forKey: Keys.sessionToken)
    }

    func getSessionToken() -> String? {
        sharedDefaults?.string(forKey: Keys.sessionToken)
    }

    func clearSessionToken() {
        sharedDefaults?.removeObject(forKey: Keys.sessionToken)
    }

    // MARK: - Quick Commands

    func getQuickCommands() -> [QuickCommand] {
        guard let data = sharedDefaults?.data(forKey: Keys.quickCommands),
              let commands = try? JSONDecoder().decode([QuickCommand].self, from: data) else {
            return QuickCommand.defaultCommands
        }
        return commands
    }

    func saveQuickCommands(_ commands: [QuickCommand]) {
        if let data = try? JSONEncoder().encode(commands) {
            sharedDefaults?.set(data, forKey: Keys.quickCommands)
        }
    }

    // MARK: - Conversation Context

    func saveRecentCompletions(_ completions: [AICompletion]) {
        // Only keep last 10 for memory efficiency
        let limited = Array(completions.prefix(10))
        if let data = try? JSONEncoder().encode(limited) {
            sharedDefaults?.set(data, forKey: Keys.recentCompletions)
        }
    }

    func getRecentCompletions() -> [AICompletion] {
        guard let data = sharedDefaults?.data(forKey: Keys.recentCompletions),
              let completions = try? JSONDecoder().decode([AICompletion].self, from: data) else {
            return []
        }
        return completions
    }

    func saveClipboardContext(_ text: String) {
        sharedDefaults?.set(text, forKey: Keys.clipboardContext)
    }

    func getClipboardContext() -> String? {
        sharedDefaults?.string(forKey: Keys.clipboardContext)
    }

    // MARK: - File Sharing (for larger data)

    /// Get shared container URL for file-based sharing
    func getSharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Save data to shared container
    func saveToSharedContainer(data: Data, filename: String) throws {
        guard let containerURL = getSharedContainerURL() else {
            throw SharedDataError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }

    /// Load data from shared container
    func loadFromSharedContainer(filename: String) throws -> Data {
        guard let containerURL = getSharedContainerURL() else {
            throw SharedDataError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(filename)
        return try Data(contentsOf: fileURL)
    }

    /// Delete file from shared container
    func deleteFromSharedContainer(filename: String) throws {
        guard let containerURL = getSharedContainerURL() else {
            throw SharedDataError.containerNotFound
        }

        let fileURL = containerURL.appendingPathComponent(filename)
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Sync

    func synchronize() {
        sharedDefaults?.synchronize()
    }
}

// MARK: - Supporting Types

enum KeyboardTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .auto: return "Auto"
        }
    }
}

struct QuickCommand: Codable, Identifiable {
    let id: UUID
    let trigger: String
    let prompt: String
    let icon: String
    var isEnabled: Bool

    init(id: UUID = UUID(), trigger: String, prompt: String, icon: String, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.prompt = prompt
        self.icon = icon
        self.isEnabled = isEnabled
    }

    static let defaultCommands: [QuickCommand] = [
        QuickCommand(
            trigger: "/ai",
            prompt: "Answer this question concisely: {input}",
            icon: "sparkles"
        ),
        QuickCommand(
            trigger: "/translate",
            prompt: "Translate this to English: {input}",
            icon: "globe"
        ),
        QuickCommand(
            trigger: "/improve",
            prompt: "Improve this text professionally: {input}",
            icon: "wand.and.stars"
        ),
        QuickCommand(
            trigger: "/summarize",
            prompt: "Summarize this in 2-3 sentences: {input}",
            icon: "list.bullet.clipboard"
        ),
        QuickCommand(
            trigger: "/fix",
            prompt: "Fix grammar and spelling: {input}",
            icon: "checkmark.circle"
        ),
        QuickCommand(
            trigger: "/explain",
            prompt: "Explain this simply: {input}",
            icon: "lightbulb"
        ),
        QuickCommand(
            trigger: "/formal",
            prompt: "Make this more formal: {input}",
            icon: "briefcase"
        ),
        QuickCommand(
            trigger: "/casual",
            prompt: "Make this more casual: {input}",
            icon: "person.2"
        )
    ]
}

struct AICompletion: Codable, Identifiable {
    let id: UUID
    let prompt: String
    let completion: String
    let modelId: String
    let timestamp: Date

    init(id: UUID = UUID(), prompt: String, completion: String, modelId: String, timestamp: Date = Date()) {
        self.id = id
        self.prompt = prompt
        self.completion = completion
        self.modelId = modelId
        self.timestamp = timestamp
    }
}

enum SharedDataError: Error {
    case containerNotFound
    case fileNotFound
    case encodingFailed
    case decodingFailed
}
