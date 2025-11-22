//
//  iPadMainView.swift
//  HuggingChat-iOS
//
//  iPad-optimized layout with split view
//

import SwiftUI

struct iPadMainView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Environment(MenuViewModel.self) private var menuViewModel
    @Environment(ThemingEngine.self) private var themingEngine

    @State private var selectedConversation: Conversation?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Conversation List
            ConversationSidebarView(selectedConversation: $selectedConversation)
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            // Detail - Chat View
            if let conversation = selectedConversation {
                ChatDetailView(conversation: conversation)
            } else {
                iPadEmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ConversationSidebarView: View {
    @Environment(MenuViewModel.self) private var menuViewModel
    @Environment(ThemingEngine.self) private var themingEngine

    @Binding var selectedConversation: Conversation?
    @State private var showingNewChatSheet = false

    var body: some View {
        List(selection: $selectedConversation) {
            ForEach(Array(menuViewModel.conversations.keys.sorted()), id: \.self) { section in
                if let conversations = menuViewModel.conversations[section], !conversations.isEmpty {
                    Section(section) {
                        ForEach(conversations) { conversation in
                            ConversationRow(conversation: conversation)
                                .tag(conversation)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await menuViewModel.deleteConversation(conversation)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Conversations")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewChatSheet = true
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Task {
                        await menuViewModel.refreshConversations()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingNewChatSheet) {
            NewConversationSheet()
        }
        .refreshable {
            await menuViewModel.refreshConversations()
        }
        .task {
            if menuViewModel.conversations.isEmpty {
                await menuViewModel.getConversations()
            }
        }
    }
}

struct iPadEmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("No Conversation Selected")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Select a conversation from the sidebar or create a new one")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    iPadMainView()
        .environment(HuggingChatSession.shared)
        .environment(ConversationViewModel())
        .environment(MenuViewModel())
        .environment(ThemingEngine())
}
