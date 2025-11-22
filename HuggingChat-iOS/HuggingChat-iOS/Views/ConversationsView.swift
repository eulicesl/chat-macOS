//
//  ConversationsView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct ConversationsView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(MenuViewModel.self) private var menuViewModel
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Environment(ThemingEngine.self) private var themingEngine

    @State private var showingNewChatSheet = false
    @State private var selectedConversation: Conversation?

    var body: some View {
        NavigationStack {
            Group {
                if menuViewModel.isLoading && menuViewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if menuViewModel.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListView
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewChatSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
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
            .navigationDestination(item: $selectedConversation) { conversation in
                ChatDetailView(conversation: conversation)
            }
        }
        .task {
            if menuViewModel.conversations.isEmpty {
                await menuViewModel.getConversations()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary)

            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a new chat to begin")
                .foregroundStyle(.secondary)

            Button {
                showingNewChatSheet = true
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .padding()
                    .background(themingEngine.currentTheme.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }

    private var conversationListView: some View {
        List {
            ForEach(Array(menuViewModel.conversations.keys.sorted()), id: \.self) { section in
                if let conversations = menuViewModel.conversations[section], !conversations.isEmpty {
                    Section(section) {
                        ForEach(conversations) { conversation in
                            ConversationRow(conversation: conversation)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedConversation = conversation
                                }
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
        .listStyle(.insetGrouped)
        .refreshable {
            await menuViewModel.refreshConversations()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conversation.title)
                .font(.headline)
                .foregroundStyle(themingEngine.currentTheme.textColor)
                .lineLimit(1)

            HStack {
                Text(conversation.modelId.split(separator: "/").last.map(String.init) ?? conversation.modelId)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(conversation.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ConversationsView()
        .environment(HuggingChatSession.shared)
        .environment(MenuViewModel())
        .environment(ConversationViewModel())
        .environment(ThemingEngine())
}
