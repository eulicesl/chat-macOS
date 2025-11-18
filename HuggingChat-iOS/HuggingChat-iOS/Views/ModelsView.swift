//
//  ModelsView.swift
//  HuggingChat-iOS
//

import SwiftUI

struct ModelsView: View {
    @Environment(HuggingChatSession.self) private var session
    @Environment(ModelManager.self) private var modelManager
    @Environment(ThemingEngine.self) private var themingEngine

    var body: some View {
        NavigationStack {
            List {
                // Cloud models section
                Section("Cloud Models") {
                    if session.availableLLM.isEmpty {
                        ProgressView("Loading models...")
                    } else {
                        ForEach(session.availableLLM) { model in
                            CloudModelRow(model: model)
                        }
                    }
                }

                // Local models section
                Section("Local Models") {
                    ForEach(modelManager.availableModels) { model in
                        LocalModelRow(model: model)
                    }
                }
            }
            .navigationTitle("Models")
        }
        .task {
            if session.availableLLM.isEmpty {
                await loadModels()
            }
        }
    }

    private func loadModels() async {
        do {
            let models = try await NetworkService.shared.getModels()
            await MainActor.run {
                session.availableLLM = models
            }
        } catch {
            print("Failed to load models: \(error)")
        }
    }
}

struct CloudModelRow: View {
    let model: LLMModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.displayName)
                .font(.headline)

            if let description = model.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack {
                if model.multimodal == true {
                    Label("Multimodal", systemImage: "photo")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }

                if model.tools == true {
                    Label("Tools", systemImage: "wrench.and.screwdriver")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LocalModelRow: View {
    let model: LocalModel
    @Environment(ModelManager.self) private var modelManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.displayName)
                    .font(.headline)

                Text(model.hfURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if case .downloading(let progress) = model.downloadState {
                    ProgressView(value: progress)
                        .tint(.blue)
                }
            }

            Spacer()

            switch model.downloadState {
            case .notDownloaded:
                Button {
                    Task {
                        await modelManager.loadModel(model)
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                }

            case .downloading:
                ProgressView()

            case .downloaded:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Button {
                        modelManager.unloadModel()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.red)
                    }
                }

            case .failed:
                Button {
                    Task {
                        await modelManager.loadModel(model)
                    }
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModelsView()
        .environment(HuggingChatSession.shared)
        .environment(ModelManager())
        .environment(ThemingEngine())
}
