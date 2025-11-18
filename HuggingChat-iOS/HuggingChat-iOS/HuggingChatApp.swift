//
//  HuggingChatApp.swift
//  HuggingChat-iOS
//
//  Created by Claude on iOS
//

import SwiftUI

@main
struct HuggingChatApp: App {
    @StateObject private var session = HuggingChatSession.shared
    @StateObject private var conversationViewModel = ConversationViewModel()
    @StateObject private var menuViewModel = MenuViewModel()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var audioModelManager = AudioModelManager()
    @StateObject private var themingEngine = ThemingEngine()
    @StateObject private var coordinatorModel = CoordinatorModel()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

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
                        .preferredColorScheme(themingEngine.currentTheme.colorScheme)
                } else {
                    OnboardingView()
                        .environment(session)
                        .environment(coordinatorModel)
                }
            }
        }
    }
}
