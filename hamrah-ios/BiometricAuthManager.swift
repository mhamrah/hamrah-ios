//
//  BiometricAuthManager.swift
//  hamrahIOS
//
//  Cross-platform biometric authentication manager.
//  iOS / macOS (Touch ID / Face ID / Optic ID). Gracefully degrades when
//  LocalAuthentication framework or hardware is unavailable.
//
//  On macOS devices without Touch ID (or in CI), all biometric operations
//  report unavailable without throwing, allowing the app to still function.
//

import Foundation
import SwiftUI

#if canImport(LocalAuthentication)
    import LocalAuthentication
#endif

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var isBiometricEnabled = false
    #if canImport(LocalAuthentication)
        @Published var biometricType: LABiometryType = .none
    #else
        // Fallback placeholder when LocalAuthentication isn't present
        @Published var biometricType: Int = 0
    #endif
    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    #if canImport(LocalAuthentication)
        private let context = LAContext()
    #else
        private let context: Any? = nil
    #endif
    private let biometricEnabledKey = "hamrah_biometric_enabled"

    init() {
        checkBiometricCapability()
        loadBiometricSettings()
    }

    // MARK: - Capability

    private func checkBiometricCapability() {
        #if canImport(LocalAuthentication)
            var error: NSError?
            // Attempt evaluation (safe probe)
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            else {
                if let e = error {
                    print("⚠️ Biometrics not available: \(e.localizedDescription)")
                } else {
                    print("⚠️ Biometrics not available (unknown reason)")
                }
                biometricType = .none
                return
            }
            biometricType = context.biometryType
            print("✅ Biometric type available: \(biometricTypeString)")
        #else
            print(
                "ℹ️ LocalAuthentication not available on this platform build; disabling biometrics.")
        #endif
    }

    // MARK: - Computed Helpers

    var biometricTypeString: String {
        #if canImport(LocalAuthentication)
            switch biometricType {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .opticID: return "Optic ID"
            case .none: return "None"
            @unknown default: return "Unknown"
            }
        #else
            return "Unavailable"
        #endif
    }

    var isAvailable: Bool {
        #if canImport(LocalAuthentication)
            return biometricType != .none
        #else
            return false
        #endif
    }

    // MARK: - Authentication

    func authenticateWithBiometrics(
        reason: String = "Authenticate to access your account"
    ) async -> Bool {
        guard isAvailable else {
            errorMessage = "Biometric authentication is not available on this device"
            return false
        }
        #if !canImport(LocalAuthentication)
            errorMessage = "Biometric framework not present in this build"
            return false
        #else
            isAuthenticating = true
            errorMessage = nil

            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: reason
                )
                if success {
                    print("✅ Biometric authentication successful")
                    isAuthenticating = false
                    return true
                }
            } catch let error as LAError {
                handleBiometricError(error)
            } catch {
                errorMessage = "Biometric authentication failed: \(error.localizedDescription)"
                print("❌ Biometric authentication error: \(error)")
            }

            isAuthenticating = false
            return false
        #endif
    }

    #if canImport(LocalAuthentication)
        private func handleBiometricError(_ error: LAError) {
            switch error.code {
            case .userCancel:
                errorMessage = "Authentication was cancelled"
            case .userFallback:
                errorMessage = "User chose fallback authentication"
            case .biometryNotAvailable:
                errorMessage = "Biometric authentication is not available"
            case .biometryNotEnrolled:
                errorMessage = "\(biometricTypeString) is not set up"
            case .biometryLockout:
                errorMessage = "Too many attempts. Use device passcode."
            case .authenticationFailed:
                errorMessage = "Failed to verify your identity"
            case .invalidContext:
                errorMessage = "Authentication context invalid"
            case .notInteractive:
                errorMessage = "Authentication not interactive"
            case .passcodeNotSet:
                errorMessage = "Device passcode not set"
            case .systemCancel:
                errorMessage = "Authentication cancelled by system"
            case .appCancel:
                errorMessage = "Authentication cancelled by app"
            case .invalidDimensions:
                errorMessage = "Invalid biometric data"
            #if os(watchOS)
                case .watchNotAvailable:
                    errorMessage = "Apple Watch unavailable"
            #endif
            case .biometryDisconnected:
                errorMessage = "Biometric sensor disconnected"
            case .touchIDNotAvailable:
                errorMessage = "Touch ID not available"
            case .touchIDNotEnrolled:
                errorMessage = "Touch ID not set up"
            case .touchIDLockout:
                errorMessage = "Touch ID locked. Use passcode."
            case .watchNotAvailable:
                errorMessage = "Apple Watch not available"
            case .biometryNotPaired:
                errorMessage = "Biometric device not paired"
            @unknown default:
                errorMessage = "Unknown biometric error"
            }
            print("❌ Biometric error: \(errorMessage ?? "Unknown")")
        }
    #else
        // Stub to satisfy calls when framework absent
        private func handleBiometricError(_ error: Error) {
            errorMessage = "Biometric authentication not supported"
        }
    #endif

    // MARK: - Settings

    func enableBiometricAuth() async -> Bool {
        let success = await authenticateWithBiometrics(
            reason: "Enable \(biometricTypeString) for quick access"
        )
        if success {
            isBiometricEnabled = true
            saveBiometricSettings()
            print("✅ Biometric authentication enabled")
        }
        return success
    }

    func disableBiometricAuth() {
        isBiometricEnabled = false
        saveBiometricSettings()
        print("🔐 Biometric authentication disabled")
    }

    private func saveBiometricSettings() {
        UserDefaults.standard.set(isBiometricEnabled, forKey: biometricEnabledKey)
    }

    private func loadBiometricSettings() {
        isBiometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }

    // MARK: - Launch Flow

    func shouldRequireBiometricAuth() -> Bool {
        isBiometricEnabled && isAvailable
    }

    func authenticateForAppAccess() async -> Bool {
        guard shouldRequireBiometricAuth() else { return true }
        return await authenticateWithBiometrics(
            reason: "Unlock Hamrah App with \(biometricTypeString)"
        )
    }
}
