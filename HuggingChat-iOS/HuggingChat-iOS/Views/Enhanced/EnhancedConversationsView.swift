//
//  EnhancedConversationsView.swift
//  HuggingChat-iOS
//
//  Enhanced conversations view with context menus and all new features
//

import SwiftUI

struct EnhancedConversationsView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(MenuViewModel.self) private var menuViewModel
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Environment(ThemingEngine.self) private var themingEngine

    @State private var showingNewChatSheet = false
    @State private var selectedConversation: Conversation?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if menuViewModel.isLoading && menuViewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                } else if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationListView
                }
            }
            .navigationTitle("Chats")
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingNewChatSheet = true
                            HapticManager.shared.light()
                        } label: {
                            Label("New Chat", systemImage: "square.and.pencil")
                        }

                        Button {
                            Task {
                                await menuViewModel.refreshConversations()
                                HapticManager.shared.success()
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button {
                            // Export conversations
                            HapticManager.shared.light()
                        } label: {
                            Label("Export All", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            // Clear all
                            HapticManager.shared.warning()
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await menuViewModel.refreshConversations()
                            HapticManager.shared.success()
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
                EnhancedChatDetailView(conversation: conversation)
            }
        }
        .task {
            if menuViewModel.conversations.isEmpty {
                await menuViewModel.getConversations()
            }
            TipsManager.shared.configureTips()
            TipsManager.shared.incrementAppOpenCount()
        }
    }

    private var filteredConversations: [String: [Conversation]] {
        if searchText.isEmpty {
            return menuViewModel.conversations
        } else {
            var filtered: [String: [Conversation]] = [:]
            for (section, conversations) in menuViewModel.conversations {
                let matchingConvos = conversations.filter { conversation in
                    conversation.title.localizedCaseInsensitiveContains(searchText)
                }
                if !matchingConvos.isEmpty {
                    filtered[section] = matchingConvos
                }
            }
            return filtered
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.badge.waveform")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            Text("No conversations yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a new chat to begin")
                .foregroundStyle(.secondary)

            Button {
                showingNewChatSheet = true
                HapticManager.shared.light()
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
            ForEach(Array(filteredConversations.keys.sorted()), id: \.self) { section in
                if let conversations = filteredConversations[section], !conversations.isEmpty {
                    Section(section) {
                        ForEach(conversations) { conversation in
                            EnhancedConversationRow(conversation: conversation)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedConversation = conversation
                                    HapticManager.shared.selection()

                                    // Start Handoff
                                    HandoffManager.shared.startHandoff(for: conversation)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            await deleteConversation(conversation)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        shareConversation(conversation)
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(.blue)
                                }
                                .contextMenu {
                                    conversationContextMenu(for: conversation)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await menuViewModel.refreshConversations()
            HapticManager.shared.success()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func conversationContextMenu(for conversation: Conversation) -> some View {
        Button {
            selectedConversation = conversation
            HapticManager.shared.light()
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
        }

        Button {
            shareConversation(conversation)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button {
            // Pin conversation
            HapticManager.shared.light()
        } label: {
            Label("Pin", systemImage: "pin")
        }

        Divider()

        Button {
            // Rename
            HapticManager.shared.light()
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            // Duplicate
            HapticManager.shared.light()
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        if #available(iOS 17.4, *) {
            Button {
                translateConversation(conversation)
            } label: {
                Label("Translate", systemImage: "character.bubble")
            }
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await deleteConversation(conversation)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func deleteConversation(_ conversation: Conversation) async {
        await menuViewModel.deleteConversation(conversation)
        HapticManager.shared.deleteItem()

        // Remove from Spotlight
        SpotlightIndexer.shared.removeConversation(conversation.id)
    }

    private func shareConversation(_ conversation: Conversation) {
        let shareText = """
        Conversation: \(conversation.title)
        Model: \(conversation.modelId)
        Last updated: \(conversation.updatedAt.formatted())
        """

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        HapticManager.shared.light()
    }

    @available(iOS 17.4, *)
    private func translateConversation(_ conversation: Conversation) {
        Task {
            if #available(iOS 26.0, *) {
                let targetLanguage = Locale.Language(identifier: "es") // Spanish as example

                for message in conversation.messages {
                    let translated = try? await TranslationManager.shared.translate(
                        message.content,
                        to: targetLanguage
                    )
                    print("Translated: \(translated ?? message.content)")
                }
            } else {
                print("Translation requires iOS 26.0 or later")
            }

            HapticManager.shared.success()
        }
    }
}

// MARK: - Enhanced Conversation Row

struct EnhancedConversationRow: View {
    let conversation: Conversation
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: conversationIcon)
                .font(.title2)
                .foregroundStyle(conversationColor)
                .frame(width: 40, height: 40)
                .background(conversationColor.opacity(0.2))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(conversation.title)
                    .font(.headline)
                    .foregroundStyle(themingEngine.currentTheme.textColor)
                    .lineLimit(1)

                HStack {
                    Text(modelDisplayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(conversation.updatedAt.timeAgo())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var conversationIcon: String {
        if conversation.messages.isEmpty {
            return "message"
        } else if conversation.messages.count < 5 {
            return "message.fill"
        } else {
            return "message.badge.filled.fill"
        }
    }

    private var conversationColor: Color {
        let hash = conversation.id.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan]
        return colors[abs(hash) % colors.count]
    }

    private var modelDisplayName: String {
        conversation.modelId.split(separator: "/").last.map(String.init) ?? conversation.modelId
    }
}

#Preview {
    EnhancedConversationsView()
        .environment(HuggingChatSession.shared)
        .environment(MenuViewModel())
        .environment(ConversationViewModel())
        .environment(ThemingEngine())
}
