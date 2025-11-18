//
//  HuggingChatApp.swift
//  HuggingChat-iOS
//
//  Created by Claude on iOS
//  Enhanced with latest Apple features and Apple Intelligence
//

import SwiftUI
import TipKit
import ActivityKit

@main
struct HuggingChatApp: App {
    // Core View Models
    @StateObject private var session = HuggingChatSession.shared
    @StateObject private var conversationViewModel = ConversationViewModel()
    @StateObject private var menuViewModel = MenuViewModel()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var audioModelManager = AudioModelManager()
    @StateObject private var themingEngine = ThemingEngine()
    @StateObject private var coordinatorModel = CoordinatorModel()

    // Enhanced Managers
    @StateObject private var liveActivityManager = LiveActivityManager()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Configure TipKit on app launch
        TipsManager.shared.configureTips()

        // Configure App Shortcuts
        AppShortcutsProvider.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding && session.token != nil {
                    MainTabView()
                        .environment(session)
                        .environment(conversationViewModel)
                        .environment(menuViewModel)
                        .environment(modelManager)
                        .environment(audioModelManager)
                        .environment(themingEngine)
                        .environment(liveActivityManager)
                        .preferredColorScheme(themingEngine.currentTheme.colorScheme)
                        .onAppear {
                            setupAppFeatures()
                        }
                        .onContinueUserActivity("com.huggingface.huggingchat.conversation") { userActivity in
                            handleHandoff(userActivity)
                        }
                        .onOpenURL { url in
                            handleURL(url)
                        }
                } else {
                    OnboardingView()
                        .environment(session)
                        .environment(coordinatorModel)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
            }
        }
    }

    // MARK: - Setup

    private func setupAppFeatures() {
        // Index conversations in Spotlight
        Task {
            await indexConversationsInSpotlight()
        }

        // Request notification permissions if needed
        requestNotificationPermissions()

        // Track app launch for tips
        TipsManager.shared.incrementAppOpenCount()
    }

    private func indexConversationsInSpotlight() async {
        let conversations = session.conversations
        SpotlightIndexer.shared.indexConversations(conversations)
    }

    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Handoff

    private func handleHandoff(_ userActivity: NSUserActivity) {
        guard let conversationId = HandoffManager.continueActivity(userActivity) else {
            return
        }

        // Find and open conversation
        if let conversation = session.conversations.first(where: { $0.id == conversationId }) {
            Task {
                await conversationViewModel.loadConversation(conversation)
            }
        }

        HapticManager.shared.success()
    }

    // MARK: - URL Handling

    private func handleURL(_ url: URL) {
        guard url.scheme == "huggingchat" else { return }

        switch url.host {
        case "share":
            handleSharedContent()

        case "conversation":
            if let conversationId = url.pathComponents.dropFirst().first {
                openConversation(id: conversationId)
            }

        case "new":
            createNewConversation()

        default:
            break
        }
    }

    private func handleSharedContent() {
        guard let defaults = UserDefaults(suiteName: "group.com.huggingface.huggingchat"),
              let sharedText = defaults.string(forKey: "sharedText") else {
            return
        }

        // Create new conversation with shared text
        Task {
            if let firstModel = session.availableLLM.first {
                await conversationViewModel.createNewConversation(modelId: firstModel.id)
                await conversationViewModel.sendMessage(sharedText)

                // Clear shared text
                defaults.removeObject(forKey: "sharedText")
            }
        }

        HapticManager.shared.success()
    }

    private func openConversation(id: String) {
        if let conversation = session.conversations.first(where: { $0.id == id }) {
            Task {
                await conversationViewModel.loadConversation(conversation)
            }
        }
    }

    private func createNewConversation() {
        Task {
            if let firstModel = session.availableLLM.first {
                await conversationViewModel.createNewConversation(modelId: firstModel.id)
            }
        }
    }

    // MARK: - Scene Phase Changes

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active
            Task {
                await menuViewModel.refreshConversations()
            }

        case .inactive:
            // App became inactive
            break

        case .background:
            // App went to background
            HandoffManager.shared.stopHandoff()

            // Save any pending data
            session.saveSession()

        @unknown default:
            break
        }
    }
}

// MARK: - UserNotifications Import

import UserNotifications
