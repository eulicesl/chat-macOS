//
//  VisionAnalyzer.swift
//  HuggingChat-iOS
//
//  Vision framework integration for image analysis
//

import Vision
import UIKit
import CoreImage

@Observable
class VisionAnalyzer {
    static let shared = VisionAnalyzer()

    var isAnalyzing = false
    var analysisResults: ImageAnalysisResult?

    private init() {}

    // MARK: - Image Analysis

    func analyzeImage(_ image: UIImage) async throws -> ImageAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        var result = ImageAnalysisResult()

        // Run multiple analyses in parallel
        async let text = detectText(in: cgImage)
        async let objects = detectObjects(in: cgImage)
        async let faces = detectFaces(in: cgImage)
        async let classification = classifyImage(cgImage)
        async let saliency = analyzeSaliency(in: cgImage)

        result.detectedText = try await text
        result.detectedObjects = try await objects
        result.detectedFaces = try await faces
        result.classification = try await classification
        result.saliencyRegions = try await saliency

        analysisResults = result
        return result
    }

    // MARK: - Text Detection

    private func detectText(in image: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Object Detection

    private func detectObjects(in image: CGImage) async throws -> [DetectedObject] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeAnimalsRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let objects = observations.compactMap { observation in
                    DetectedObject(
                        label: observation.labels.first?.identifier ?? "Unknown",
                        confidence: Double(observation.confidence),
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: objects)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Face Detection

    private func detectFaces(in image: CGImage) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: 0)
                    return
                }

                continuation.resume(returning: observations.count)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Image Classification

    private func classifyImage(_ image: CGImage) async throws -> [ImageClassification] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let classifications = observations.prefix(5).map { observation in
                    ImageClassification(
                        label: observation.identifier,
                        confidence: Double(observation.confidence)
                    )
                }

                continuation.resume(returning: Array(classifications))
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Saliency Analysis

    private func analyzeSaliency(in image: CGImage) async throws -> [SaliencyRegion] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNSaliencyImageObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let regions = observations.compactMap { observation -> SaliencyRegion? in
                    guard let objects = observation.salientObjects else { return nil }

                    return objects.map { object in
                        SaliencyRegion(
                            boundingBox: object.boundingBox,
                            confidence: Double(object.confidence)
                        )
                    }.first
                }

                continuation.resume(returning: regions)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Generate Description

    func generateImageDescription(_ result: ImageAnalysisResult) -> String {
        var description = "Image analysis: "

        if !result.classification.isEmpty {
            let topClass = result.classification.first!
            description += "Contains \(topClass.label.lowercased())"
        }

        if result.detectedFaces > 0 {
            description += ", \(result.detectedFaces) face(s) detected"
        }

        if !result.detectedObjects.isEmpty {
            let objectLabels = result.detectedObjects.map { $0.label }.joined(separator: ", ")
            description += ", objects: \(objectLabels)"
        }

        if !result.detectedText.isEmpty {
            description += ", text: \"\(result.detectedText.joined(separator: " "))\""
        }

        return description
    }
}

// MARK: - Supporting Types

struct ImageAnalysisResult {
    var detectedText: [String] = []
    var detectedObjects: [DetectedObject] = []
    var detectedFaces: Int = 0
    var classification: [ImageClassification] = []
    var saliencyRegions: [SaliencyRegion] = []
}

struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Double
    let boundingBox: CGRect
}

struct ImageClassification: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Double
}

struct SaliencyRegion: Identifiable {
    let id = UUID()
    let boundingBox: CGRect
    let confidence: Double
}

enum VisionError: Error, LocalizedError {
    case invalidImage
    case analysisFailure

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided"
        case .analysisFailure:
            return "Image analysis failed"
        }
    }
}
