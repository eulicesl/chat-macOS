//
//  ContextProvider.swift
//  HuggingChat-iOS
//
//  Provides contextual information from device and apps
//

import Foundation
import UIKit
import Observation

@Observable
final class ContextProvider: @unchecked Sendable {
    static let shared = ContextProvider()

    var currentContext: DeviceContext?
    var clipboardHistory: [ClipboardItem] = []
    var isMonitoring = false

    private var clipboardTimer: Timer?

    private init() {
        startMonitoring()
    }

    // MARK: - Device Context

    func getCurrentContext() -> DeviceContext {
        let context = DeviceContext(
            deviceModel: getDeviceModel(),
            osVersion: getOSVersion(),
            currentApp: getCurrentApp(),
            batteryLevel: getBatteryLevel(),
            isLowPowerMode: isLowPowerModeEnabled(),
            networkType: getNetworkType(),
            currentLocation: nil, // Requires location permissions
            timeOfDay: getTimeOfDay(),
            dayOfWeek: getDayOfWeek(),
            clipboardContent: getClipboardContent()
        )

        currentContext = context
        return context
    }

    // MARK: - Clipboard Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }

        isMonitoring = true

        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    private func checkClipboard() {
        guard let string = UIPasteboard.general.string else { return }

        // Check if this is new content
        if let lastItem = clipboardHistory.first, lastItem.content == string {
            return
        }

        let item = ClipboardItem(
            content: string,
            timestamp: Date(),
            type: .text
        )

        clipboardHistory.insert(item, at: 0)

        // Keep only last 10 items
        if clipboardHistory.count > 10 {
            clipboardHistory = Array(clipboardHistory.prefix(10))
        }

        // Store in memory
        MemoryManager.shared.storeContextualInfo(
            context: "Clipboard: \(string.prefix(100))...",
            source: "clipboard",
            importance: 0.4
        )
    }

    func getClipboardHistory(limit: Int = 5) -> [ClipboardItem] {
        return Array(clipboardHistory.prefix(limit))
    }

    // MARK: - Screen Content (Future: iOS 18+)

    func captureScreenContent() -> String? {
        // This would use iOS 18's Screen Intelligence APIs when available
        // For now, return placeholder
        return nil
    }

    // MARK: - App Context

    func getRecentApps() -> [String] {
        // This would require private APIs or iOS 18 features
        // For now, return placeholder
        return []
    }

    // MARK: - Private Helpers

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private func getOSVersion() -> String {
        return UIDevice.current.systemVersion
    }

    private func getCurrentApp() -> String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }

    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }

    private func isLowPowerModeEnabled() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    private func getNetworkType() -> NetworkType {
        // Simplified network type detection
        // In production, use Network framework for detailed info
        return .wifi
    }

    private func getTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }

    private func getDayOfWeek() -> Int {
        return Calendar.current.component(.weekday, from: Date())
    }

    private func getClipboardContent() -> String? {
        return UIPasteboard.general.string
    }
}

// MARK: - Supporting Types

struct DeviceContext: Codable {
    let deviceModel: String
    let osVersion: String
    let currentApp: String
    let batteryLevel: Float
    let isLowPowerMode: Bool
    let networkType: NetworkType
    let currentLocation: String?
    let timeOfDay: TimeOfDay
    let dayOfWeek: Int
    let clipboardContent: String?

    var contextString: String {
        """
        Device: \(deviceModel)
        OS: iOS \(osVersion)
        Time: \(timeOfDay.rawValue)
        Battery: \(Int(batteryLevel * 100))%
        Low Power Mode: \(isLowPowerMode ? "Yes" : "No")
        Network: \(networkType.rawValue)
        """
    }
}

struct ClipboardItem: Identifiable, Codable {
    let id = UUID()
    let content: String
    let timestamp: Date
    let type: ClipboardType

    enum ClipboardType: String, Codable {
        case text
        case url
        case image
    }
}

enum NetworkType: String, Codable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case offline = "Offline"
}

enum TimeOfDay: String, Codable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
}
