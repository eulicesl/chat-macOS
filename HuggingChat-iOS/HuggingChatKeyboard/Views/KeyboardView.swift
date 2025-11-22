//
//  KeyboardView.swift
//  HuggingChatKeyboard
//
//  Main SwiftUI view for the custom keyboard
//

import SwiftUI

struct KeyboardView: View {
    @Bindable var viewModel: KeyboardViewModel
    let textDocumentProxy: UITextDocumentProxy
    let requestNextKeyboard: () -> Void
    let dismissKeyboard: () -> Void

    @State private var inputText: String = ""
    @State private var showingCommands: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            KeyboardToolbar(
                viewModel: viewModel,
                requestNextKeyboard: requestNextKeyboard,
                dismissKeyboard: dismissKeyboard,
                showingCommands: $showingCommands
            )

            Divider()

            // Main content area
            ZStack {
                switch viewModel.keyboardMode {
                case .standard:
                    SuggestionsBarView(
                        suggestions: viewModel.suggestions,
                        onSelect: { suggestion in
                            insertText(suggestion)
                        }
                    )

                case .ai:
                    AIInputView(
                        viewModel: viewModel,
                        inputText: $inputText,
                        onSubmit: {
                            Task {
                                await handleAIRequest(inputText)
                            }
                        }
                    )

                case .voice:
                    VoiceInputView(
                        viewModel: viewModel,
                        onTranscription: { text in
                            insertText(text)
                        }
                    )

                case .commands:
                    CommandsGridView(
                        commands: viewModel.quickCommands,
                        onSelect: { command in
                            handleCommandSelect(command)
                        }
                    )
                }
            }
            .frame(height: viewModel.keyboardMode == .ai ? 200 : 150)
        }
        .background(keyboardBackground)
    }

    private var keyboardBackground: some View {
        Group {
            switch viewModel.selectedTheme {
            case .light:
                Color(UIColor.systemGray6)
            case .dark:
                Color(UIColor.systemGray5)
            case .auto:
                Color(UIColor.systemBackground)
            }
        }
    }

    // MARK: - Actions

    private func insertText(_ text: String) {
        textDocumentProxy.insertText(text)
    }

    private func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    private func handleAIRequest(_ prompt: String) async {
        guard !prompt.isEmpty else { return }

        await viewModel.executeAIRequest(prompt)
        inputText = ""
    }

    private func handleCommandSelect(_ command: QuickCommand) {
        viewModel.switchMode(.ai)
        inputText = command.trigger + " "
    }
}

// MARK: - Keyboard Toolbar

struct KeyboardToolbar: View {
    @Bindable var viewModel: KeyboardViewModel
    let requestNextKeyboard: () -> Void
    let dismissKeyboard: () -> Void
    @Binding var showingCommands: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Globe button (switch keyboard)
            Button(action: requestNextKeyboard) {
                Image(systemName: "globe")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Mode toggles
            HStack(spacing: 8) {
                ModeButton(
                    icon: "keyboard",
                    isActive: viewModel.keyboardMode == .standard,
                    action: { viewModel.switchMode(.standard) }
                )

                ModeButton(
                    icon: "sparkles",
                    isActive: viewModel.keyboardMode == .ai,
                    action: { viewModel.switchMode(.ai) }
                )

                if viewModel.enableVoiceInput {
                    ModeButton(
                        icon: "mic.fill",
                        isActive: viewModel.keyboardMode == .voice,
                        action: { viewModel.switchMode(.voice) }
                    )
                }

                ModeButton(
                    icon: "command",
                    isActive: viewModel.keyboardMode == .commands,
                    action: { viewModel.switchMode(.commands) }
                )
            }

            Spacer()

            // Dismiss button
            Button(action: dismissKeyboard) {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.systemBackground).opacity(0.9))
    }
}

struct ModeButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 40, height: 32)
                .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                .cornerRadius(8)
        }
    }
}

// MARK: - Suggestions Bar

struct SuggestionsBarView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if suggestions.isEmpty {
                    Text("Start typing to see suggestions...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: { onSelect(suggestion) }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .cornerRadius(16)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - AI Input View

struct AIInputView: View {
    @Bindable var viewModel: KeyboardViewModel
    @Binding var inputText: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Input field
            HStack {
                TextField("Ask AI anything...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit(onSubmit)

                Button(action: onSubmit) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(inputText.isEmpty ? Color.secondary : Color.accentColor)
                    }
                }
                .disabled(inputText.isEmpty || viewModel.isLoading)
            }
            .padding(.horizontal)

            // Recent completions
            if !viewModel.recentCompletions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.recentCompletions.prefix(5)) { completion in
                                RecentCompletionCard(completion: completion) {
                                    insertCompletion(completion.completion)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }

            if !viewModel.allowNetworkAccess {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Network access disabled. Enable in HuggingChat app settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func insertCompletion(_ text: String) {
        // Insert completion into text field
        viewModel.textDocumentProxy?.insertText(text)
    }
}

struct RecentCompletionCard: View {
    let completion: AICompletion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(completion.prompt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(completion.completion)
                    .font(.caption)
                    .lineLimit(2)
            }
            .frame(width: 150, alignment: .leading)
            .padding(8)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - Voice Input View

struct VoiceInputView: View {
    @Bindable var viewModel: KeyboardViewModel
    let onTranscription: (String) -> Void

    @State private var isRecording: Bool = false
    @State private var audioLevel: CGFloat = 0.0

    var body: some View {
        VStack(spacing: 16) {
            // Audio visualization
            HStack(spacing: 4) {
                ForEach(0..<20) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isRecording ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 3, height: isRecording ? CGFloat.random(in: 10...60) : 10)
                        .animation(.easeInOut(duration: 0.3).repeatForever(), value: isRecording)
                }
            }
            .frame(height: 60)

            // Record button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.accentColor)
                        .frame(width: 64, height: 64)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
            }

            Text(isRecording ? "Tap to stop recording" : "Tap to start recording")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleRecording() {
        isRecording.toggle()

        if isRecording {
            // Start recording
            startRecording()
        } else {
            // Stop and transcribe
            stopRecording()
        }
    }

    private func startRecording() {
        Task {
            await viewModel.startVoiceRecording()
        }
    }

    private func stopRecording() {
        viewModel.stopVoiceRecording()
    }
}

// MARK: - Commands Grid View

struct CommandsGridView: View {
    let commands: [QuickCommand]
    let onSelect: (QuickCommand) -> Void

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(commands.filter(\.isEnabled)) { command in
                    CommandCard(command: command) {
                        onSelect(command)
                    }
                }
            }
            .padding()
        }
    }
}

struct CommandCard: View {
    let command: QuickCommand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: command.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.accentColor)

                Text(command.trigger)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(command.prompt.replacingOccurrences(of: "{input}", with: "..."))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}
