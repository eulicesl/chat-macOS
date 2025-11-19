//
//  AccessibilityManager.swift
//  HuggingChat
//
//  Accessibility features for keyboard and main app
//  VoiceOver, Dynamic Type, High Contrast, Reduced Motion support
//

import SwiftUI
import Observation

/// Manages accessibility features across the app
@Observable
class AccessibilityManager {
    static let shared = AccessibilityManager()

    // Accessibility settings
    var isVoiceOverEnabled: Bool = false
    var preferredContentSizeCategory: ContentSizeCategory = .large
    var isHighContrastEnabled: Bool = false
    var isReducedMotionEnabled: Bool = false
    var isReducedTransparencyEnabled: Bool = false
    var isBoldTextEnabled: Bool = false

    // Keyboard-specific
    var largerKeyboardButtons: Bool = false
    var enhancedTouchTargets: Bool = false
    var hapticFeedbackLevel: HapticLevel = .medium

    private init() {
        detectAccessibilitySettings()
        setupNotifications()
    }

    // MARK: - Detection

    private func detectAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isReducedMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReducedTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled

        // Determine larger buttons based on multiple factors
        largerKeyboardButtons = isVoiceOverEnabled || preferredContentSizeCategory >= .extraExtraLarge
        enhancedTouchTargets = isVoiceOverEnabled || preferredContentSizeCategory >= .extraLarge
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectAccessibilitySettings()
        }

        NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectAccessibilitySettings()
        }
    }

    // MARK: - Dynamic Type

    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size).weight(weight)
    }

    func buttonHeight() -> CGFloat {
        switch preferredContentSizeCategory {
        case .accessibilityExtraExtraExtraLarge,
             .accessibilityExtraExtraLarge,
             .accessibilityExtraLarge:
            return 60
        case .accessibilityLarge,
             .accessibilityMedium:
            return 52
        case .extraExtraExtraLarge,
             .extraExtraLarge:
            return 48
        default:
            return 44
        }
    }

    func minimumTouchTarget() -> CGFloat {
        enhancedTouchTargets ? 48 : 44
    }

    // MARK: - Colors

    func accessibleColor(light: Color, dark: Color, highContrast: Color) -> Color {
        if isHighContrastEnabled {
            return highContrast
        }
        return Color.primary // Adapts to light/dark mode
    }

    func backgroundColor() -> Color {
        if isHighContrastEnabled {
            return Color.black
        }
        if isReducedTransparencyEnabled {
            return Color(UIColor.systemBackground)
        }
        return Color(UIColor.systemBackground).opacity(0.95)
    }

    // MARK: - Animations

    func animation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        EmptyView().animation(isReducedMotionEnabled ? nil : animation, value: value)
    }

    func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result {
        if isReducedMotionEnabled {
            return try body()
        } else {
            return try SwiftUI.withAnimation(animation, body)
        }
    }

    // MARK: - VoiceOver

    func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func screenChanged(to element: Any?) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }

    func layoutChanged(to element: Any?) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }

    // MARK: - Haptics

    func hapticFeedback(for style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedbackLevel != .off else { return }

        let generator: UIImpactFeedbackGenerator

        switch hapticFeedbackLevel {
        case .light:
            generator = UIImpactFeedbackGenerator(style: .light)
        case .medium:
            generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:
            generator = UIImpactFeedbackGenerator(style: .heavy)
        case .off:
            return
        }

        generator.impactOccurred()
    }

    func selectionHaptic() {
        guard hapticFeedbackLevel != .off else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func notificationHaptic(type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticFeedbackLevel != .off else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - Haptic Level

enum HapticLevel: String, Codable, CaseIterable {
    case off = "Off"
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"
}

// MARK: - Accessibility View Modifiers

extension View {
    func accessibleButton(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }

    func accessibleImage(label: String, isDecorative: Bool = false) -> some View {
        self
            .accessibilityLabel(isDecorative ? "" : label)
            .accessibilityHidden(isDecorative)
    }

    func minimumAccessibleTapArea() -> some View {
        let manager = AccessibilityManager.shared
        return self.frame(minWidth: manager.minimumTouchTarget(), minHeight: manager.minimumTouchTarget())
    }

    func adaptiveAnimation(_ animation: Animation) -> some View {
        let manager = AccessibilityManager.shared
        return self.animation(manager.isReducedMotionEnabled ? nil : animation)
    }
}

// MARK: - High Contrast Color Scheme

struct HighContrastColors {
    static let foreground = Color.primary
    static let background = Color(UIColor.systemBackground)
    static let accent = Color.blue
    static let success = Color.green
    static let error = Color.red
    static let warning = Color.orange
}
