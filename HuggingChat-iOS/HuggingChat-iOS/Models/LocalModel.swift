//
//  LocalModel.swift
//  HuggingChat-iOS
//

import Foundation

struct LocalModel: Identifiable, Hashable {
    let displayName: String
    let hfURL: String
    var localURL: URL?
    var downloadState: DownloadState
    let modelType: ModelType

    var id: String { hfURL }

    enum DownloadState: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(error: String)
    }

    enum ModelType: String {
        case qwen = "Qwen2.5-3B-Instruct-4bit"
        case smolLM = "SmolLM-135M-Instruct-4bit"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocalModel, rhs: LocalModel) -> Bool {
        lhs.id == rhs.id
    }
}

extension LocalModel {
    static let availableModels: [LocalModel] = [
        LocalModel(
            displayName: "Qwen 2.5 3B Instruct",
            hfURL: "mlx-community/Qwen2.5-3B-Instruct-4bit",
            localURL: nil,
            downloadState: .notDownloaded,
            modelType: .qwen
        ),
        LocalModel(
            displayName: "SmolLM 135M Instruct",
            hfURL: "mlx-community/SmolLM-135M-Instruct-4bit",
            localURL: nil,
            downloadState: .notDownloaded,
            modelType: .smolLM
        )
    ]
}
