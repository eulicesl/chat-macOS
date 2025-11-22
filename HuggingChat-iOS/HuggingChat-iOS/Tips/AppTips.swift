//
//  AppTips.swift
//  HuggingChat-iOS
//
//  TipKit integration for contextual onboarding
//

import TipKit

// MARK: - Voice Input Tip

struct VoiceInputTip: Tip {
    var title: Text {
        Text("Use Voice Input")
    }

    var message: Text? {
        Text("Tap the microphone to speak your message instead of typing")
    }

    var image: Image? {
        Image(systemName: "mic.fill")
    }

    var actions: [Action] {
        [
            Action(id: "try-voice", title: "Try It")
        ]
    }

    // Rules
    @Parameter
    static var hasUsedVoiceInput: Bool = false

    @Parameter
    static var messagesSent: Int = 0

    var rules: [Rule] {
        [
            #Rule(Self.$hasUsedVoiceInput) { !$0 },
            #Rule(Self.$messagesSent) { $0 >= 3 }
        ]
    }
}

// MARK: - Web Search Tip

struct WebSearchTip: Tip {
    var title: Text {
        Text("Enable Web Search")
    }

    var message: Text? {
        Text("Get up-to-date information by enabling web search for your queries")
    }

    var image: Image? {
        Image(systemName: "magnifyingglass")
    }

    var actions: [Action] {
        [
            Action(id: "enable-search", title: "Enable")
        ]
    }

    @Parameter
    static var hasUsedWebSearch: Bool = false

    @Parameter
    static var conversationsCreated: Int = 0

    var rules: [Rule] {
        [
            #Rule(Self.$hasUsedWebSearch) { !$0 },
            #Rule(Self.$conversationsCreated) { $0 >= 2 }
        ]
    }
}

// MARK: - Local Model Tip

struct LocalModelTip: Tip {
    var title: Text {
        Text("Try Local Models")
    }

    var message: Text? {
        Text("Download a model to run AI on-device, even without internet")
    }

    var image: Image? {
        Image(systemName: "cpu")
    }

    var actions: [Action] {
        [
            Action(id: "download-model", title: "Download"),
            Action(id: "learn-more", title: "Learn More")
        ]
    }

    @Parameter
    static var hasDownloadedModel: Bool = false

    @Parameter
    static var appOpenCount: Int = 0

    var rules: [Rule] {
        [
            #Rule(Self.$hasDownloadedModel) { !$0 },
            #Rule(Self.$appOpenCount) { $0 >= 5 }
        ]
    }
}

// MARK: - Theme Customization Tip

struct ThemeCustomizationTip: Tip {
    var title: Text {
        Text("Customize Your Theme")
    }

    var message: Text? {
        Text("Choose from multiple themes in Settings to personalize your experience")
    }

    var image: Image? {
        Image(systemName: "paintbrush.fill")
    }

    var actions: [Action] {
        [
            Action(id: "open-themes", title: "Open Settings")
        ]
    }

    @Parameter
    static var hasChangedTheme: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$hasChangedTheme) { !$0 }
        ]
    }
}

// MARK: - Siri Shortcuts Tip

struct SiriShortcutsTip: Tip {
    var title: Text {
        Text("Add to Siri")
    }

    var message: Text? {
        Text("Create Siri shortcuts to start conversations with your voice")
    }

    var image: Image? {
        Image(systemName: "mic.badge.plus")
    }

    var actions: [Action] {
        [
            Action(id: "add-shortcut", title: "Add Shortcut")
        ]
    }

    @Parameter
    static var hasCreatedShortcut: Bool = false

    @Parameter
    static var messagesSent: Int = 0

    var rules: [Rule] {
        [
            #Rule(Self.$hasCreatedShortcut) { !$0 },
            #Rule(Self.$messagesSent) { $0 >= 10 }
        ]
    }
}

// MARK: - Tips Configuration

@Observable
final class TipsManager: @unchecked Sendable {
    static let shared = TipsManager()

    private init() {}

    func configureTips() {
        // Configure TipKit on app launch
        try? Tips.configure([
            .displayFrequency(.daily),
            .datastoreLocation(.applicationDefault)
        ])
    }

    func resetAllTips() {
        try? Tips.resetDatastore()
    }

    // Update parameters
    func markVoiceInputUsed() {
        VoiceInputTip.hasUsedVoiceInput = true
    }

    func incrementMessagesSent() {
        VoiceInputTip.messagesSent += 1
        SiriShortcutsTip.messagesSent += 1
    }

    func markWebSearchUsed() {
        WebSearchTip.hasUsedWebSearch = true
    }

    func incrementConversationsCreated() {
        WebSearchTip.conversationsCreated += 1
    }

    func markModelDownloaded() {
        LocalModelTip.hasDownloadedModel = true
    }

    func incrementAppOpenCount() {
        LocalModelTip.appOpenCount += 1
    }

    func markThemeChanged() {
        ThemeCustomizationTip.hasChangedTheme = true
    }

    func markShortcutCreated() {
        SiriShortcutsTip.hasCreatedShortcut = true
    }
}
