//
//  ChatDetailView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct ChatDetailView: View {
    let conversation: Conversation

    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(ThemingEngine.self) private var themingEngine
    @Environment(\.dismiss) private var dismiss

    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if viewModel.isInteracting {
                            HStack {
                                ProgressView()
                                    .padding(.horizontal, 8)
                                Text("Thinking...")
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    scrollToBottom()
                }
            }

            Divider()

            // Input Area
            InputView()
                .focused($isInputFocused)
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Edit title
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        Task {
                            await viewModel.clearConversation()
                            dismiss()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .background(themingEngine.currentTheme.backgroundColor)
        .task {
            await viewModel.loadConversation(conversation)
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: MessageRow
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.type == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 8) {
                // Message content
                MessageContentView(content: message.content)
                    .padding(12)
                    .background(
                        message.type == .user
                            ? themingEngine.currentTheme.userMessageBackground
                            : themingEngine.currentTheme.assistantMessageBackground
                    )
                    .cornerRadius(16)

                // Web search sources
                if let webSearch = message.webSearch, let sources = webSearch.sources {
                    WebSearchSourcesView(sources: sources)
                }

                // Timestamp
                if let createdAt = message.createdAt {
                    Text(createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if message.type == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

struct MessageContentView: View {
    let content: String
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        Text(content)
            .textSelection(.enabled)
            .foregroundStyle(themingEngine.currentTheme.textColor)
    }
}

struct WebSearchSourcesView: View {
    let sources: [WebSearchSource]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(sources.prefix(3)) { source in
                Link(destination: URL(string: source.link)!) {
                    HStack {
                        Image(systemName: "link")
                            .font(.caption)
                        VStack(alignment: .leading) {
                            Text(source.title)
                                .font(.caption)
                                .lineLimit(1)
                            Text(source.hostname)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack {
        ChatDetailView(conversation: .preview)
            .environment(ConversationViewModel())
            .environment(ThemingEngine())
    }
}
