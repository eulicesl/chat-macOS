//
//  HapticManager.swift
//  HuggingChat-iOS
//
//  Haptic feedback manager for enhanced tactile experience
//

import SwiftUI
import UIKit
import CoreHaptics

@Observable
final class HapticManager: @unchecked Sendable {
    static let shared = HapticManager()

    private var engine: CHHapticEngine?
    private var supportsHaptics = false

    private init() {
        setupHapticEngine()
    }

    // MARK: - Setup

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
            supportsHaptics = true

            // Reset engine on background/foreground
            engine?.stoppedHandler = { reason in
                print("Haptic engine stopped: \(reason)")
            }

            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                try? self?.engine?.start()
            }
        } catch {
            print("Failed to create haptic engine: \(error)")
            supportsHaptics = false
        }
    }

    // MARK: - Simple Haptics

    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }

    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }

    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    // MARK: - Custom Haptic Patterns

    func messageReceived() {
        guard supportsHaptics else {
            light()
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.1
            )
        ]

        playPattern(events: events)
    }

    func messageGenerating() {
        guard supportsHaptics else {
            soft()
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0,
                duration: 0.5
            )
        ]

        playPattern(events: events)
    }

    func messageComplete() {
        guard supportsHaptics else {
            success()
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.05
            )
        ]

        playPattern(events: events)
    }

    func deleteItem() {
        guard supportsHaptics else {
            rigid()
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 0
            )
        ]

        playPattern(events: events)
    }

    func swipeAction() {
        guard supportsHaptics else {
            medium()
            return
        }

        let events = [
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            )
        ]

        playPattern(events: events)
    }

    // MARK: - Pattern Playback

    private func playPattern(events: [CHHapticEvent]) {
        guard supportsHaptics, let engine = engine else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
}

// MARK: - View Extension

extension View {
    func hapticFeedback(on trigger: some Equatable, feedback: @escaping () -> Void) -> some View {
        self.onChange(of: trigger) { _, _ in
            feedback()
        }
    }

    func onTapHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    let generator = UIImpactFeedbackGenerator(style: style)
                    generator.impactOccurred()
                }
        )
    }
}
