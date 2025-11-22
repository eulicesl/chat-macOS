//
//  InputView.swift
//  HuggingChat-iOS
//

import SwiftUI
import PhotosUI

struct InputView: View {
    @Environment(ConversationViewModel.self) private var viewModel
    @Environment(AudioModelManager.self) private var audioManager
    @Environment(ThemingEngine.self) private var themingEngine

    @State private var inputText = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isRecording = false
    @State private var showingPhotoPicker = false

    var body: some View {
        VStack(spacing: 8) {
            // Options bar
            HStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { viewModel.useWebSearch },
                    set: { viewModel.useWebSearch = $0 }
                )) {
                    Label("Web Search", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(themingEngine.currentTheme.accentColor)

                Toggle(isOn: Binding(
                    get: { viewModel.useLocalModel },
                    set: { viewModel.useLocalModel = $0 }
                )) {
                    Label("Local", systemImage: "cpu")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(themingEngine.currentTheme.accentColor)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Input field
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                Button {
                    showingPhotoPicker = true
                } label: {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(themingEngine.currentTheme.accentColor)
                }
                .disabled(viewModel.isInteracting)

                // Text input
                TextField("Message", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .disabled(viewModel.isInteracting)

                // Voice button
                Button {
                    if isRecording {
                        Task {
                            await audioManager.stopRecording()
                            inputText = audioManager.currentText
                            isRecording = false
                        }
                    } else {
                        Task {
                            try? await audioManager.startRecording()
                            isRecording = true
                        }
                    }
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
        }
        .background(themingEngine.currentTheme.inputBackground)
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5)
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""

        Task {
            await viewModel.sendMessage(text, files: nil)
        }
    }
}

#Preview {
    InputView()
        .environment(ConversationViewModel())
        .environment(AudioModelManager())
        .environment(ThemingEngine())
}
