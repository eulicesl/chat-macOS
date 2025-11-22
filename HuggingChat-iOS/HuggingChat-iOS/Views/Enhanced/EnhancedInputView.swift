//
//  EnhancedInputView.swift
//  HuggingChat-iOS
//
//  Enhanced input view with all new Apple features
//

import SwiftUI
import PhotosUI
import TipKit

struct EnhancedInputView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(AudioModelManager.self) private var audioManager
    @Environment(ThemingEngine.self) private var themingEngine

    @State private var inputText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isRecording = false
    @State private var showingPhotoPicker = false
    @State private var showingWritingTools = false
    @State private var showingSmartReplies = false
    @State private var smartReplies: [String] = []
    @State private var analyzedImage: ImageAnalysisResult?

    // Tips
    private let voiceTip = VoiceInputTip()
    private let webSearchTip = WebSearchTip()

    var body: some View {
        VStack(spacing: 8) {
            // Tips
            TipView(voiceTip, arrowEdge: .bottom)
                .padding(.horizontal)

            TipView(webSearchTip, arrowEdge: .bottom)
                .padding(.horizontal)

            // Smart replies (if available)
            if showingSmartReplies && !smartReplies.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(smartReplies, id: \.self) { reply in
                            Button {
                                inputText = reply
                                showingSmartReplies = false
                                HapticManager.shared.selection()
                            } label: {
                                Text(reply)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // Options bar
            HStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { viewModel.useWebSearch },
                    set: {
                        viewModel.useWebSearch = $0
                        HapticManager.shared.selection()
                        if $0 {
                            TipsManager.shared.markWebSearchUsed()
                        }
                    }
                )) {
                    Label("Web Search", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(themingEngine.currentTheme.accentColor)

                Toggle(isOn: Binding(
                    get: { viewModel.useLocalModel },
                    set: {
                        viewModel.useLocalModel = $0
                        HapticManager.shared.selection()
                    }
                )) {
                    Label("Local", systemImage: "cpu")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(themingEngine.currentTheme.accentColor)

                Spacer()

                // Writing tools button
                Button {
                    showingWritingTools.toggle()
                    HapticManager.shared.light()
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Input field
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                Button {
                    showingPhotoPicker = true
                    HapticManager.shared.light()
                } label: {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(themingEngine.currentTheme.accentColor)
                }
                .disabled(viewModel.isInteracting)
                .contextMenu {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Photo Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        // Camera
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }

                    Button {
                        // Files
                    } label: {
                        Label("Browse Files", systemImage: "folder")
                    }
                }

                // Text input with context menu
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .disabled(viewModel.isInteracting)
                    .contextMenu {
                        Button {
                            pasteAndAnalyze()
                        } label: {
                            Label("Paste and Analyze", systemImage: "doc.on.clipboard")
                        }

                        if !inputText.isEmpty {
                            Button {
                                improveText()
                            } label: {
                                Label("Improve Writing", systemImage: "wand.and.stars")
                            }

                            Button {
                                summarizeText()
                            } label: {
                                Label("Summarize", systemImage: "text.alignleft")
                            }
                        }
                    }
                    .onChange(of: inputText) { oldValue, newValue in
                        if newValue.isEmpty && !oldValue.isEmpty {
                            generateSmartReplies()
                        }
                    }

                // Voice button
                Button {
                    handleVoiceInput()
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic")
                        .font(.title3)
                        .foregroundStyle(isRecording ? .red : themingEngine.currentTheme.accentColor)
                }
                .disabled(viewModel.isInteracting)

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(inputText.isEmpty ? .secondary : themingEngine.currentTheme.accentColor)
                }
                .disabled(inputText.isEmpty || viewModel.isInteracting)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Image analysis results
            if let analysis = analyzedImage {
                ImageAnalysisCard(analysis: analysis)
                    .padding(.horizontal)
            }
        }
        .background(themingEngine.currentTheme.inputBackground)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5)
        .onChange(of: selectedPhotos) { _, newPhotos in
            handlePhotoSelection(newPhotos)
        }
        .sheet(isPresented: $showingWritingTools) {
            WritingToolsSheet(text: $inputText)
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText
        inputText = ""

        Task {
            await viewModel.sendMessage(text, files: nil)
            HapticManager.shared.messageReceived()
            TipsManager.shared.incrementMessagesSent()
        }
    }

    private func handleVoiceInput() {
        if isRecording {
            Task {
                await audioManager.stopRecording()
                inputText = audioManager.currentText
                isRecording = false
                HapticManager.shared.messageComplete()
                TipsManager.shared.markVoiceInputUsed()
            }
        } else {
            Task {
                try? await audioManager.startRecording()
                isRecording = true
                HapticManager.shared.messageGenerating()
            }
        }
    }

    private func handlePhotoSelection(_ photos: [PhotosPickerItem]) {
        guard let firstPhoto = photos.first else { return }

        Task {
            if let data = try? await firstPhoto.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {

                // Analyze image
                let result = try? await VisionAnalyzer.shared.analyzeImage(image)
                analyzedImage = result

                if let result = result {
                    let description = VisionAnalyzer.shared.generateImageDescription(result)
                    inputText += "\n\n[Image: \(description)]"
                }

                HapticManager.shared.success()
            }
        }
    }

    private func pasteAndAnalyze() {
        if let string = UIPasteboard.general.string {
            inputText = string

            // Analyze sentiment
            let sentiment = WritingToolsManager.shared.analyzeSentiment(string)
            print("Sentiment: \(sentiment)")

            HapticManager.shared.light()
        }
    }

    private func improveText() {
        let improved = WritingToolsManager.shared.enhanceText(inputText)
        inputText = improved
        HapticManager.shared.success()
    }

    private func summarizeText() {
        let summary = WritingToolsManager.shared.summarize(inputText)
        inputText = summary
        HapticManager.shared.success()
    }

    private func generateSmartReplies() {
        guard let lastMessage = viewModel.messages.last?.content else { return }

        smartReplies = WritingToolsManager.shared.generateSmartReplies(for: lastMessage)
        showingSmartReplies = !smartReplies.isEmpty
    }
}

// MARK: - Image Analysis Card

struct ImageAnalysisCard: View {
    let analysis: ImageAnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "eye")
                    .foregroundStyle(.blue)
                Text("Image Analysis")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    // Dismiss
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            if !analysis.classification.isEmpty {
                Text("Contains: \(analysis.classification.first!.label)")
                    .font(.caption2)
            }

            if analysis.detectedFaces > 0 {
                Text("\(analysis.detectedFaces) face(s) detected")
                    .font(.caption2)
            }

            if !analysis.detectedText.isEmpty {
                Text("Text: \"\(analysis.detectedText.joined(separator: " "))\"")
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Writing Tools Sheet

struct WritingToolsSheet: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Improve") {
                    Button {
                        text = WritingToolsManager.shared.enhanceText(text)
                        HapticManager.shared.success()
                    } label: {
                        Label("Make Professional", systemImage: "doc.text")
                    }

                    Button {
                        text = WritingToolsManager.shared.changeTone(text, to: .friendly)
                        HapticManager.shared.success()
                    } label: {
                        Label("Make Friendly", systemImage: "hand.wave")
                    }

                    Button {
                        text = WritingToolsManager.shared.changeTone(text, to: .concise)
                        HapticManager.shared.success()
                    } label: {
                        Label("Make Concise", systemImage: "text.alignleft")
                    }
                }

                Section("Transform") {
                    Button {
                        text = WritingToolsManager.shared.summarize(text)
                        HapticManager.shared.success()
                    } label: {
                        Label("Summarize", systemImage: "text.quote")
                    }

                    Button {
                        let concepts = WritingToolsManager.shared.extractKeyConcepts(from: text)
                        text += "\n\nKey concepts: \(concepts.joined(separator: ", "))"
                        HapticManager.shared.success()
                    } label: {
                        Label("Extract Key Points", systemImage: "list.bullet")
                    }
                }

                Section("Analysis") {
                    let sentiment = WritingToolsManager.shared.analyzeSentiment(text)
                    HStack {
                        Text("Sentiment")
                        Spacer()
                        Text(sentiment.emoji)
                            .font(.title2)
                    }

                    if let language = WritingToolsManager.shared.detectLanguage(text) {
                        HStack {
                            Text("Language")
                            Spacer()
                            Text(Locale.current.localizedString(forIdentifier: language) ?? language)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Writing Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnhancedInputView()
        .environment(ConversationViewModel())
        .environment(AudioModelManager())
        .environment(ThemingEngine())
}
