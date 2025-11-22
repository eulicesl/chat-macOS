//
//  OfflineModelManager.swift
//  HuggingChat
//
//  Manages offline AI models (WhisperKit, MLX Swift) for keyboard and main app
//

import Foundation
import Observation

/// Manages downloading, storage, and lifecycle of offline AI models
@Observable
final class OfflineModelManager: @unchecked Sendable {
    static let shared = OfflineModelManager()

    // Model storage
    private let sharedData = SharedDataManager.shared
    private let fileManager = FileManager.default

    // State
    var availableWhisperModels: [WhisperModel] = []
    var availableMLXModels: [MLXModel] = []
    var downloadingModels: Set<String> = []
    var downloadProgress: [String: Double] = [:]
    var installedModels: [String: ModelInfo] = [:]

    // Settings
    var preferOfflineMode: Bool = false
    var autoDownloadOnWiFi: Bool = true
    var maxStorageUsage: Int64 = 2_000_000_000 // 2GB default

    private init() {
        loadInstalledModels()
        setupAvailableModels()
    }

    // MARK: - Available Models

    private func setupAvailableModels() {
        availableWhisperModels = [
            WhisperModel(
                id: "whisper-tiny",
                name: "Tiny",
                size: 75_000_000, // 75MB
                languages: ["en"],
                description: "Fastest, English-only, good for quick transcription",
                accuracy: .good
            ),
            WhisperModel(
                id: "whisper-base",
                name: "Base",
                size: 142_000_000, // 142MB
                languages: ["en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru", "zh"],
                description: "Balanced speed and accuracy, supports 10 languages",
                accuracy: .veryGood
            ),
            WhisperModel(
                id: "whisper-small",
                name: "Small",
                size: 466_000_000, // 466MB
                languages: ["en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru", "zh", "ja", "ko"],
                description: "High accuracy, supports 12 languages",
                accuracy: .excellent
            ),
            WhisperModel(
                id: "whisper-medium",
                name: "Medium",
                size: 1_500_000_000, // 1.5GB
                languages: ["multi"], // Supports 90+ languages
                description: "Best accuracy, supports 90+ languages, slower",
                accuracy: .excellent
            )
        ]

        availableMLXModels = [
            MLXModel(
                id: "mlx-phi-3-mini",
                name: "Phi-3 Mini",
                size: 2_300_000_000, // 2.3GB
                parameters: "3.8B",
                description: "Small but capable, fast inference, good for short responses",
                contextLength: 4096,
                speed: .fast
            ),
            MLXModel(
                id: "mlx-llama-3.2-1b",
                name: "Llama 3.2 1B",
                size: 1_000_000_000, // 1GB
                parameters: "1B",
                description: "Ultra-fast, lightweight, good for quick completions",
                contextLength: 2048,
                speed: .veryFast
            ),
            MLXModel(
                id: "mlx-llama-3.2-3b",
                name: "Llama 3.2 3B",
                size: 3_000_000_000, // 3GB
                parameters: "3B",
                description: "Balanced performance, good general-purpose model",
                contextLength: 8192,
                speed: .fast
            ),
            MLXModel(
                id: "mlx-gemma-2b",
                name: "Gemma 2B",
                size: 2_000_000_000, // 2GB
                parameters: "2B",
                description: "Google's efficient model, great for conversation",
                contextLength: 8192,
                speed: .fast
            )
        ]
    }

    // MARK: - Model Management

    /// Checks if a model is installed
    func isModelInstalled(_ modelId: String) -> Bool {
        installedModels[modelId] != nil
    }

    /// Gets the path to an installed model
    func getModelPath(_ modelId: String) -> URL? {
        guard let containerURL = sharedData.getSharedContainerURL() else {
            return nil
        }

        let modelsPath = containerURL.appendingPathComponent("Models")
        let modelPath = modelsPath.appendingPathComponent(modelId)

        return fileManager.fileExists(atPath: modelPath.path) ? modelPath : nil
    }

    /// Downloads a model
    func downloadModel(_ modelId: String) async throws {
        guard !downloadingModels.contains(modelId) else {
            throw ModelError.alreadyDownloading
        }

        guard !isModelInstalled(modelId) else {
            throw ModelError.alreadyInstalled
        }

        // Check storage space
        try checkStorageSpace(for: modelId)

        await MainActor.run {
            downloadingModels.insert(modelId)
            downloadProgress[modelId] = 0.0
        }

        defer {
            Task { @MainActor in
                downloadingModels.remove(modelId)
                downloadProgress.removeValue(forKey: modelId)
            }
        }

        // Get model URL (placeholder - would use HuggingFace Hub in production)
        let downloadURL = try getModelDownloadURL(modelId)

        // Download with progress
        let localURL = try await downloadModelFile(from: downloadURL, modelId: modelId)

        // Install model
        try installModel(localURL, modelId: modelId)

        await MainActor.run {
            installedModels[modelId] = ModelInfo(
                id: modelId,
                installedDate: Date(),
                size: getModelSize(modelId),
                version: "1.0"
            )
            saveInstalledModels()
        }
    }

    /// Deletes a model
    func deleteModel(_ modelId: String) throws {
        guard let modelPath = getModelPath(modelId) else {
            throw ModelError.modelNotFound
        }

        try fileManager.removeItem(at: modelPath)
        installedModels.removeValue(forKey: modelId)
        saveInstalledModels()
    }

    /// Gets total storage used by models
    func getTotalStorageUsed() -> Int64 {
        var total: Int64 = 0

        for info in installedModels.values {
            total += info.size
        }

        return total
    }

    /// Gets available storage space
    func getAvailableStorage() -> Int64 {
        guard let containerURL = sharedData.getSharedContainerURL() else {
            return 0
        }

        do {
            let values = try containerURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Private Helpers

    private func checkStorageSpace(for modelId: String) throws {
        let modelSize = getModelSize(modelId)
        let availableSpace = getAvailableStorage()
        let currentUsage = getTotalStorageUsed()

        // Check if we have enough space
        guard availableSpace > modelSize else {
            throw ModelError.insufficientStorage
        }

        // Check if it would exceed user's limit
        guard currentUsage + modelSize <= maxStorageUsage else {
            throw ModelError.storageLimitExceeded
        }
    }

    private func getModelSize(_ modelId: String) -> Int64 {
        if let whisper = availableWhisperModels.first(where: { $0.id == modelId }) {
            return whisper.size
        }
        if let mlx = availableMLXModels.first(where: { $0.id == modelId }) {
            return mlx.size
        }
        return 0
    }

    private func getModelDownloadURL(_ modelId: String) throws -> URL {
        // In production, this would construct HuggingFace Hub URLs
        // For now, placeholder
        guard let url = URL(string: "https://huggingface.co/models/\(modelId)") else {
            throw ModelError.invalidURL
        }
        return url
    }

    private func downloadModelFile(from url: URL, modelId: String) async throws -> URL {
        // Create download task with progress tracking
        let (localURL, response) = try await URLSession.shared.download(from: url) { progress in
            Task { @MainActor in
                self.downloadProgress[modelId] = progress
            }
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelError.downloadFailed
        }

        return localURL
    }

    private func installModel(_ sourceURL: URL, modelId: String) throws {
        guard let containerURL = sharedData.getSharedContainerURL() else {
            throw ModelError.containerNotFound
        }

        let modelsPath = containerURL.appendingPathComponent("Models")

        // Create Models directory if needed
        if !fileManager.fileExists(atPath: modelsPath.path) {
            try fileManager.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }

        let destinationURL = modelsPath.appendingPathComponent(modelId)

        // Move downloaded file to models directory
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    private func loadInstalledModels() {
        guard let data = try? sharedData.loadFromSharedContainer(filename: "installed_models.json"),
              let models = try? JSONDecoder().decode([String: ModelInfo].self, from: data) else {
            return
        }
        installedModels = models
    }

    private func saveInstalledModels() {
        guard let data = try? JSONEncoder().encode(installedModels) else {
            return
        }
        try? sharedData.saveToSharedContainer(data: data, filename: "installed_models.json")
    }
}

// MARK: - URLSession Extension for Progress

extension URLSession {
    func download(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> (URL, URLResponse) {
        // Simple wrapper - in production, use custom delegate for progress
        try await download(from: url)
    }
}

// MARK: - Model Types

struct WhisperModel: Identifiable, Codable {
    let id: String
    let name: String
    let size: Int64
    let languages: [String]
    let description: String
    let accuracy: ModelAccuracy

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var languageList: String {
        if languages.contains("multi") {
            return "90+ languages"
        }
        return languages.joined(separator: ", ")
    }
}

struct MLXModel: Identifiable, Codable {
    let id: String
    let name: String
    let size: Int64
    let parameters: String
    let description: String
    let contextLength: Int
    let speed: ModelSpeed

    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct ModelInfo: Codable {
    let id: String
    let installedDate: Date
    let size: Int64
    let version: String
}

enum ModelAccuracy: String, Codable {
    case good = "Good"
    case veryGood = "Very Good"
    case excellent = "Excellent"
}

enum ModelSpeed: String, Codable {
    case veryFast = "Very Fast"
    case fast = "Fast"
    case moderate = "Moderate"
    case slow = "Slow"
}

enum ModelError: Error, LocalizedError {
    case alreadyDownloading
    case alreadyInstalled
    case modelNotFound
    case insufficientStorage
    case storageLimitExceeded
    case invalidURL
    case downloadFailed
    case containerNotFound
    case installationFailed

    var errorDescription: String? {
        switch self {
        case .alreadyDownloading:
            return "Model is already being downloaded"
        case .alreadyInstalled:
            return "Model is already installed"
        case .modelNotFound:
            return "Model not found"
        case .insufficientStorage:
            return "Not enough storage space available"
        case .storageLimitExceeded:
            return "This would exceed your storage limit"
        case .invalidURL:
            return "Invalid model URL"
        case .downloadFailed:
            return "Model download failed"
        case .containerNotFound:
            return "Shared container not found"
        case .installationFailed:
            return "Model installation failed"
        }
    }
}
