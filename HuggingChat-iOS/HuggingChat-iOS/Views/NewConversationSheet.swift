//
//  NewConversationSheet.swift
//  HuggingChat-iOS
//

import SwiftUI

struct NewConversationSheet: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(ConversationViewModel.self) private var conversationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedModelId: String?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            List {
                if session.availableLLM.isEmpty {
                    ProgressView("Loading models...")
                } else {
                    ForEach(session.availableLLM) { model in
                        Button {
                            selectedModelId = model.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(model.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    if let description = model.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }

                                Spacer()

                                if selectedModelId == model.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createConversation()
                    }
                    .disabled(selectedModelId == nil || isCreating)
                }
            }
        }
        .task {
            if session.availableLLM.isEmpty {
                await loadModels()
            } else if selectedModelId == nil {
                selectedModelId = session.availableLLM.first?.id
            }
        }
    }

    private func loadModels() async {
        do {
            let models = try await NetworkService.shared.getModels()
            await MainActor.run {
                session.availableLLM = models
                selectedModelId = models.first?.id
            }
        } catch {
            print("Failed to load models: \(error)")
        }
    }

    private func createConversation() {
        guard let modelId = selectedModelId else { return }

        isCreating = true

        Task {
            await conversationViewModel.createNewConversation(modelId: modelId)
            await MainActor.run {
                isCreating = false
                dismiss()
            }
        }
    }
}

#Preview {
    NewConversationSheet()
        .environment(HuggingChatSession.shared)
        .environment(ConversationViewModel())
}
