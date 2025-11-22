//
//  BiometricAuthService.swift
//  HuggingChat
//
//  Biometric authentication using Apple's LocalAuthentication framework
//  Provides Face ID, Touch ID, and passcode authentication
//

import LocalAuthentication
import Foundation
import Observation

/// Service for biometric authentication (Face ID, Touch ID, Passcode)
@Observable
final class BiometricAuthService: @unchecked Sendable {
    static let shared = BiometricAuthService()

    // Auth state
    var isAuthenticated: Bool = false
    var biometricType: BiometricType = .none
    var lastAuthenticationDate: Date?

    // Settings
    var requireAuthOnLaunch: Bool = false
    var requireAuthForSettings: Bool = true
    var requireAuthForMemoryExport: Bool = true
    var authenticationTimeout: TimeInterval = 300 // 5 minutes

    private let context = LAContext()

    private init() {
        detectBiometricType()
    }

    // MARK: - Biometric Detection

    /// Detects available biometric authentication type
    private func detectBiometricType() {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }

        switch context.biometryType {
        case .faceID:
            biometricType = .faceID
        case .touchID:
            biometricType = .touchID
        case .opticID:
            if #available(iOS 17.0, *) {
                biometricType = .opticID
            }
        case .none:
            biometricType = .none
        @unknown default:
            biometricType = .none
        }
    }

    /// Checks if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Checks if device has passcode set
    func isPasscodeAvailable() -> Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    // MARK: - Authentication

    /// Authenticates user with biometrics (Face ID/Touch ID)
    func authenticateWithBiometrics(reason: String = "Authenticate to access HuggingChat") async throws -> Bool {
        let context = LAContext()

        // Check if biometrics are available
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw AuthenticationError.biometricError(error)
            }
            throw AuthenticationError.biometricNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticated = success
                if success {
                    lastAuthenticationDate = Date()
                }
            }

            return success
        } catch let error as LAError {
            throw AuthenticationError.authenticationFailed(error)
        }
    }

    /// Authenticates user with biometrics or passcode fallback
    func authenticateWithFallback(reason: String = "Authenticate to access HuggingChat") async throws -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                throw AuthenticationError.biometricError(error)
            }
            throw AuthenticationError.authenticationNotAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticated = success
                if success {
                    lastAuthenticationDate = Date()
                }
            }

            return success
        } catch let error as LAError {
            throw AuthenticationError.authenticationFailed(error)
        }
    }

    /// Checks if authentication is still valid (within timeout)
    func isAuthenticationValid() -> Bool {
        guard isAuthenticated, let lastAuth = lastAuthenticationDate else {
            return false
        }

        let timeSinceAuth = Date().timeIntervalSince(lastAuth)
        return timeSinceAuth < authenticationTimeout
    }

    /// Invalidates current authentication
    func invalidateAuthentication() {
        isAuthenticated = false
        lastAuthenticationDate = nil
    }

    // MARK: - Convenience Methods

    /// Authenticates for settings access
    func authenticateForSettings() async throws -> Bool {
        guard requireAuthForSettings else { return true }

        if isAuthenticationValid() {
            return true
        }

        return try await authenticateWithFallback(reason: "Authenticate to access settings")
    }

    /// Authenticates for memory export
    func authenticateForMemoryExport() async throws -> Bool {
        guard requireAuthForMemoryExport else { return true }

        return try await authenticateWithFallback(reason: "Authenticate to export memory data")
    }

    /// Authenticates on app launch
    func authenticateOnLaunch() async throws -> Bool {
        guard requireAuthOnLaunch else { return true }

        return try await authenticateWithBiometrics(reason: "Authenticate to unlock HuggingChat")
    }

    // MARK: - Biometric Information

    /// Returns user-friendly biometric name
    func getBiometricName() -> String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Passcode"
        }
    }

    /// Returns icon for biometric type
    func getBiometricIcon() -> String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock"
        }
    }
}

// MARK: - Biometric Type

enum BiometricType {
    case faceID
    case touchID
    case opticID
    case none
}

// MARK: - Authentication Errors

enum AuthenticationError: Error, LocalizedError {
    case biometricNotAvailable
    case authenticationNotAvailable
    case biometricError(Error)
    case authenticationFailed(LAError)

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationNotAvailable:
            return "Authentication is not available. Please set up Face ID, Touch ID, or a passcode"
        case .biometricError(let error):
            return "Biometric error: \(error.localizedDescription)"
        case .authenticationFailed(let laError):
            return getAuthenticationErrorMessage(laError)
        }
    }

    private func getAuthenticationErrorMessage(_ error: LAError) -> String {
        switch error.code {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .userCancel:
            return "Authentication cancelled by user"
        case .userFallback:
            return "User chose to use passcode"
        case .biometryNotAvailable:
            return "Biometric authentication is not available"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings"
        case .biometryLockout:
            return "Biometric authentication is locked. Please use passcode to unlock"
        case .passcodeNotSet:
            return "Passcode is not set. Please set up a passcode in Settings"
        case .systemCancel:
            return "Authentication cancelled by system"
        case .appCancel:
            return "Authentication cancelled by app"
        case .invalidContext:
            return "Invalid authentication context"
        case .notInteractive:
            return "Authentication not allowed in current context"
        @unknown default:
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Modifier

import SwiftUI

/// View modifier for biometric authentication
struct BiometricAuthModifier: ViewModifier {
    @State private var isUnlocked = false
    @State private var showError = false
    @State private var errorMessage = ""

    let reason: String
    let onSuccess: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if !isUnlocked {
                    BiometricLockScreen(
                        reason: reason,
                        onUnlock: {
                            isUnlocked = true
                            onSuccess()
                        },
                        onError: { error in
                            errorMessage = error
                            showError = true
                        }
                    )
                }
            }
            .alert("Authentication Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
    }
}

/// Biometric lock screen view
struct BiometricLockScreen: View {
    let reason: String
    let onUnlock: () -> Void
    let onError: (String) -> Void

    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: BiometricAuthService.shared.getBiometricIcon())
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    Text("Locked")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                Button(action: authenticate) {
                    HStack {
                        if isAuthenticating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: BiometricAuthService.shared.getBiometricIcon())
                            Text("Unlock with \(BiometricAuthService.shared.getBiometricName())")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            // Auto-trigger authentication
            authenticate()
        }
    }

    private func authenticate() {
        isAuthenticating = true

        Task {
            do {
                let success = try await BiometricAuthService.shared.authenticateWithFallback(reason: reason)

                await MainActor.run {
                    isAuthenticating = false
                    if success {
                        onUnlock()
                    }
                }
            } catch {
                await MainActor.run {
                    isAuthenticating = false
                    onError(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Requires biometric authentication to access view
    func requiresBiometricAuth(reason: String, onSuccess: @escaping () -> Void = {}) -> some View {
        modifier(BiometricAuthModifier(reason: reason, onSuccess: onSuccess))
    }
}
