//
//  VisionKitService.swift
//  HuggingChat
//
//  Live Text scanning and visual intelligence using Apple's native VisionKit
//  Provides camera-based text scanning, QR codes, and document capture
//

import SwiftUI
import VisionKit

/// Service for live text scanning and document capture using VisionKit
/// Requires iOS 16+ for DataScannerViewController
@available(iOS 16.0, *)
@Observable
class VisionKitService: NSObject {
    static let shared = VisionKitService()

    // Scanning state
    var isScanning: Bool = false
    var recognizedItems: [RecognizedItem] = []
    var lastScannedText: String = ""

    // Supported data types
    var supportedTextContentTypes: Set<DataScannerViewController.TextContentType> = [
        .URL, .emailAddress, .phoneNumber, .address, .shipmentTrackingNumber
    ]

    // Callbacks
    var onTextRecognized: ((String) -> Void)?
    var onItemsRecognized: (([RecognizedItem]) -> Void)?
    var onError: ((Error) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Availability

    /// Checks if data scanner is available on this device
    static func isSupported() -> Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isSupported
        }
        return false
    }

    /// Checks if device is available (not in use)
    static func isAvailable() -> Bool {
        if #available(iOS 16.0, *) {
            return DataScannerViewController.isAvailable
        }
        return false
    }

    // MARK: - Scanner Configuration

    /// Creates a data scanner view controller for live text scanning
    @MainActor
    func createTextScanner(
        recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [.text()],
        recognizesMultipleItems: Bool = true,
        isHighlightingEnabled: Bool = true
    ) -> DataScannerViewController? {
        guard Self.isSupported() && Self.isAvailable() else {
            return nil
        }

        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: recognizesMultipleItems,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: isHighlightingEnabled
        )

        scanner.delegate = self

        return scanner
    }

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

        // Add to recognized items
        let item = RecognizedItem(
            id: UUID(),
            type: .text,
            content: text,
            timestamp: Date()
        )
        recognizedItems.append(item)
        onItemsRecognized?(recognizedItems)
    }

    /// Clears recognized items
    func clearRecognizedItems() {
        recognizedItems.removeAll()
        lastScannedText = ""
    }
}

// MARK: - DataScannerViewControllerDelegate

@available(iOS 16.0, *)
extension VisionKitService: DataScannerViewControllerDelegate {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        switch item {
        case .text(let text):
            processRecognizedText(text.transcript)
        case .barcode(let barcode):
            if let payload = barcode.payloadStringValue {
                processRecognizedText(payload)
            }
        @unknown default:
            break
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        // Process newly added items
        for item in addedItems {
            switch item {
            case .text(let text):
                let recognizedItem = RecognizedItem(
                    id: item.id,
                    type: .text,
                    content: text.transcript,
                    timestamp: Date()
                )
                recognizedItems.append(recognizedItem)
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    let recognizedItem = RecognizedItem(
                        id: item.id,
                        type: .barcode,
                        content: payload,
                        timestamp: Date()
                    )
                    recognizedItems.append(recognizedItem)
                }
            @unknown default:
                break
            }
        }

        onItemsRecognized?(recognizedItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        // Update recognized items
        recognizedItems.removeAll { removedItem in
            removedItems.contains { $0.id == removedItem.id }
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        onError?(VisionKitError.scanningUnavailable(error))
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

@available(iOS 16.0, *)
extension VisionKitService: VNDocumentCameraViewControllerDelegate {
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

// MARK: - SwiftUI Integration

/// SwiftUI wrapper for DataScannerViewController
@available(iOS 16.0, *)
struct DataScannerView: UIViewControllerRepresentable {
    let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    let onTextRecognized: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = context.coordinator

        try? scanner.startScanning()

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onTextRecognized: (String) -> Void

        init(onTextRecognized: @escaping (String) -> Void) {
            self.onTextRecognized = onTextRecognized
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                onTextRecognized(text.transcript)
            case .barcode(let barcode):
                if let payload = barcode.payloadStringValue {
                    onTextRecognized(payload)
                }
            @unknown default:
                break
            }
        }
    }
}
