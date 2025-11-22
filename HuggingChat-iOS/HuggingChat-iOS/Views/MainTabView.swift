//
//  MainTabView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct MainTabView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Environment(MenuViewModel.self) private var menuViewModel
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        Group {
            if DeviceType.current == .iPad {
                // iPad uses NavigationSplitView for better layout
                TabView {
                    iPadMainView()
                        .tabItem {
                            Label("Chats", systemImage: "message.fill")
                        }

                    ModelsView()
                        .tabItem {
                            Label("Models", systemImage: "cpu.fill")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .tint(themingEngine.currentTheme.accentColor)
            } else {
                // iPhone uses standard TabView
                TabView {
                    ConversationsView()
                        .tabItem {
                            Label("Chats", systemImage: "message.fill")
                        }

                    ModelsView()
                        .tabItem {
                            Label("Models", systemImage: "cpu.fill")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .tint(themingEngine.currentTheme.accentColor)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(HuggingChatSession.shared)
        .environment(ConversationViewModel())
        .environment(MenuViewModel())
        .environment(ThemingEngine())
}
