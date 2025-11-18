//
//  EnhancedChatDetailView.swift
//  HuggingChat-iOS
//
//  Enhanced chat detail view with Live Activities, haptics, and more
//

import SwiftUI
import TipKit

struct EnhancedChatDetailView: View {
    let conversation: Conversation

    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(ThemingEngine.self) private var themingEngine
    @Environment(LiveActivityManager.self) private var liveActivityManager
    @Environment(\.dismiss) private var dismiss

    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showingTranslation = false
    @State private var selectedLanguage: Locale.Language?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            EnhancedMessageBubble(message: message)
                                .id(message.id)
                                .contextMenu {
                                    messageContextMenu(for: message)
                                }
                        }

                        if viewModel.isInteracting {
                            HStack {
                                TypingIndicator()
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

            // Enhanced Input Area
            EnhancedInputView()
                .focused($isInputFocused)
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        // Edit title
                        HapticManager.shared.light()
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button {
                        shareConversation()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    if #available(iOS 17.4, *) {
                        Button {
                            showingTranslation = true
                            HapticManager.shared.light()
                        } label: {
                            Label("Translate", systemImage: "character.bubble")
                        }
                    }

                    Divider()

                    Button {
                        exportConversation()
                    } label: {
                        Label("Export", systemImage: "doc.text")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            await deleteConversation()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.title)
                        .font(.headline)
                    if viewModel.isInteracting {
                        Text("Generating...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .background(themingEngine.currentTheme.backgroundColor)
        .task {
            await loadConversation()
        }
        .onChange(of: viewModel.isInteracting) { oldValue, newValue in
            handleGenerationStateChange(wasGenerating: oldValue, isGenerating: newValue)
        }
        .sheet(isPresented: $showingTranslation) {
            if #available(iOS 17.4, *) {
                TranslationSheet(messages: viewModel.messages)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func messageContextMenu(for message: MessageRow) -> some View {
        Button {
            UIPasteboard.general.string = message.content
            HapticManager.shared.light()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if message.type == .assistant {
            Button {
                // Regenerate response
                HapticManager.shared.light()
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }

            Button {
                readAloud(message.content)
            } label: {
                Label("Read Aloud", systemImage: "speaker.wave.2")
            }
        }

        if #available(iOS 17.4, *) {
            Button {
                translateMessage(message)
            } label: {
                Label("Translate", systemImage: "character.bubble")
            }
        }

        Divider()

        Button {
            shareMessage(message)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            // Delete message
            HapticManager.shared.deleteItem()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func loadConversation() async {
        await viewModel.loadConversation(conversation)

        // Start Handoff
        HandoffManager.shared.startHandoff(for: conversation)

        // Index in Spotlight
        SpotlightIndexer.shared.indexConversation(conversation)
    }

    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func handleGenerationStateChange(wasGenerating: Bool, isGenerating: Bool) {
        if isGenerating && !wasGenerating {
            // Started generating
            HapticManager.shared.messageGenerating()

            // Start Live Activity
            liveActivityManager.startGenerationActivity(
                conversationTitle: conversation.title,
                modelName: conversation.modelId.split(separator: "/").last.map(String.init) ?? "AI"
            )

        } else if !isGenerating && wasGenerating {
            // Finished generating
            HapticManager.shared.messageComplete()

            // End Live Activity
            if let lastMessage = viewModel.messages.last {
                liveActivityManager.endActivity(
                    finalMessage: lastMessage.content,
                    totalTokens: lastMessage.content.split(separator: " ").count
                )
            }

            // Update Handoff
            if let lastMessage = viewModel.messages.last {
                HandoffManager.shared.updateHandoff(with: lastMessage.content)
            }
        }
    }

    private func deleteConversation() async {
        await viewModel.clearConversation()
        HapticManager.shared.deleteItem()
        dismiss()
    }

    private func shareConversation() {
        let messages = viewModel.messages.map { message in
            let author = message.type == .user ? "You" : "AI"
            return "\(author): \(message.content)"
        }.joined(separator: "\n\n")

        let shareText = """
        Conversation: \(conversation.title)

        \(messages)
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

    private func shareMessage(_ message: MessageRow) {
        let activityVC = UIActivityViewController(
            activityItems: [message.content],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        HapticManager.shared.light()
    }

    private func exportConversation() {
        let markdown = generateMarkdownExport()

        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(conversation.title).md")

        do {
            try markdown.write(to: tempURL, atomically: true, encoding: .utf8)

            let activityVC = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                rootVC.present(activityVC, animated: true)
            }

            HapticManager.shared.success()
        } catch {
            print("Export failed: \(error)")
            HapticManager.shared.error()
        }
    }

    private func generateMarkdownExport() -> String {
        var markdown = "# \(conversation.title)\n\n"
        markdown += "**Model**: \(conversation.modelId)\n\n"
        markdown += "**Date**: \(conversation.updatedAt.formatted())\n\n"
        markdown += "---\n\n"

        for message in viewModel.messages {
            let author = message.type == .user ? "**You**" : "**AI**"
            markdown += "\(author)\n\n\(message.content)\n\n---\n\n"
        }

        return markdown
    }

    @available(iOS 17.4, *)
    private func translateMessage(_ message: MessageRow) {
        Task {
            let targetLanguage = Locale.Language(identifier: "es")
            let translated = try? await TranslationManager.shared.translate(
                message.content,
                to: targetLanguage
            )

            if let translated = translated {
                print("Translated: \(translated)")
                HapticManager.shared.success()
            }
        }
    }

    private func readAloud(_ text: String) {
        // Use AVSpeechSynthesizer for text-to-speech
        let utterance = AVSpeechUtterance(string: text)
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)

        HapticManager.shared.light()
    }
}

// MARK: - Enhanced Message Bubble

struct EnhancedMessageBubble: View {
    let message: MessageRow
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.type == .user {
                Spacer(minLength: 50)
            }

            VStack(alignment: message.type == .user ? .trailing : .leading, spacing: 8) {
                // Avatar
                if message.type == .assistant {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }

                // Message content with markdown
                MarkdownMessageView(content: message.content)
                    .padding(12)
                    .background(
                        message.type == .user
                            ? themingEngine.currentTheme.userMessageBackground
                            : themingEngine.currentTheme.assistantMessageBackground
                    )
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

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

// MARK: - Translation Sheet

@available(iOS 17.4, *)
struct TranslationSheet: View {
    let messages: [MessageRow]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage = Locale.Language(identifier: "es")

    var body: some View {
        NavigationStack {
            List {
                Section("Target Language") {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("Spanish").tag(Locale.Language(identifier: "es"))
                        Text("French").tag(Locale.Language(identifier: "fr"))
                        Text("German").tag(Locale.Language(identifier: "de"))
                        Text("Chinese").tag(Locale.Language(identifier: "zh"))
                        Text("Japanese").tag(Locale.Language(identifier: "ja"))
                    }
                }

                Section("Preview") {
                    ForEach(messages.prefix(3)) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(message.content)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            // Show translated preview
                            Text("Translation preview...")
                                .font(.body)
                        }
                    }
                }
            }
            .navigationTitle("Translate Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Translate") {
                        translateAll()
                    }
                }
            }
        }
    }

    private func translateAll() {
        Task {
            for message in messages {
                _ = try? await TranslationManager.shared.translate(
                    message.content,
                    to: selectedLanguage
                )
            }

            dismiss()
            HapticManager.shared.success()
        }
    }
}

import AVFoundation

#Preview {
    NavigationStack {
        EnhancedChatDetailView(conversation: .preview)
            .environment(ConversationViewModel())
            .environment(ThemingEngine())
            .environment(LiveActivityManager())
    }
}
