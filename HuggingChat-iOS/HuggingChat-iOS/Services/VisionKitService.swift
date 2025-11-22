//
//  VisionKitService.swift
//  HuggingChat
//
//  Live Text scanning and visual intelligence using Apple's native VisionKit
//  Provides camera-based text scanning, QR codes, and document capture
//

import SwiftUI
import VisionKit
import Vision

/// Service for live text scanning and document capture using VisionKit
/// Requires iOS 16+ for DataScannerViewController
@available(iOS 16.0, *)
@MainActor
@Observable
final class VisionKitService: NSObject {
    static let shared = VisionKitService()

    // Scanning state
    var isScanning: Bool = false
    var recognizedItems: [RecognizedItem] = []
    var lastScannedText: String = ""

    // Callbacks
    var onTextRecognized: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Availability

    /// Checks if data scanner is available on this device
    @MainActor static func isSupported() -> Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported
        }
        return false
    }

    /// Checks if device is available (not in use)
    @MainActor static func isAvailable() -> Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isAvailable
        }
        return false
    }

    // MARK: - Scanner Configuration

    /// Creates a document camera for scanning documents
    @MainActor
    func createDocumentCamera() -> VNDocumentCameraViewController {
        let documentCamera = VNDocumentCameraViewController()
        documentCamera.delegate = self
        return documentCamera
    }

    // MARK: - Processing

    /// Processes recognized text items
    func processRecognizedText(_ text: String) {
        lastScannedText = text
        onTextRecognized?(text)
    }

    /// Clears recognized items
    func clearRecognizedItems() {
        recognizedItems.removeAll()
        lastScannedText = ""
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

@available(iOS 16.0, *)
@MainActor
extension VisionKitService: @preconcurrency VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        // Process scanned document pages
        for pageIndex in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageIndex)

            // Recognize text in the scanned image
            Task {
                await recognizeText(in: image)
            }
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        // User cancelled scanning
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        onError?(error)
    }

    // Helper to recognize text in image
    private func recognizeText(in image: UIImage) async {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")

            Task { @MainActor in
                self?.processRecognizedText(recognizedText)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }
}

// MARK: - Supporting Types

struct RecognizedItem: Identifiable {
    let id: UUID
    let type: RecognizedItemType
    let content: String
    let timestamp: Date
}

enum RecognizedItemType {
    case text
    case barcode
    case qrCode
    case url
    case email
    case phone
    case address
}

enum VisionKitError: Error, LocalizedError {
    case notSupported
    case notAvailable
    case scanningUnavailable(DataScannerViewController.ScanningUnavailable)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Data scanning is not supported on this device"
        case .notAvailable:
            return "Data scanning is currently unavailable"
        case .scanningUnavailable(let reason):
            return "Scanning unavailable: \(reason)"
        }
    }
}
