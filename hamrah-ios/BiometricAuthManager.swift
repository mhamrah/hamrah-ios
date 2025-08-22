//
//  BiometricAuthManager.swift
//  hamrahIOS
//
//  Biometric authentication manager for Face ID/Touch ID support
//

import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
class BiometricAuthManager: ObservableObject {
    @Published var isBiometricEnabled = false
    @Published var biometricType: LABiometryType = .none
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    
    private let context = LAContext()
    private let biometricEnabledKey = "hamrah_biometric_enabled"
    
    init() {
        checkBiometricCapability()
        loadBiometricSettings()
    }
    
    // MARK: - Biometric Capability Check
    
    private func checkBiometricCapability() {
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("⚠️ Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            biometricType = .none
            return
        }
        
        biometricType = context.biometryType
        print("✅ Biometric type available: \(biometricTypeString)")
    }
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "None"
        @unknown default:
            return "Unknown"
        }
    }
    
    var isAvailable: Bool {
        return biometricType != .none
    }
    
    // MARK: - Authentication
    
    func authenticateWithBiometrics(reason: String = "Authenticate to access your account") async -> Bool {
        guard isAvailable else {
            errorMessage = "Biometric authentication is not available on this device"
            return false
        }
        
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
    }
    
    private func handleBiometricError(_ error: LAError) {
        switch error.code {
        case .userCancel:
            errorMessage = "Authentication was cancelled"
        case .userFallback:
            errorMessage = "User chose to use fallback authentication"
        case .biometryNotAvailable:
            errorMessage = "Biometric authentication is not available"
        case .biometryNotEnrolled:
            errorMessage = "Biometric authentication is not set up. Please set up \(biometricTypeString) in Settings"
        case .biometryLockout:
            errorMessage = "Biometric authentication is locked. Please use device passcode"
        case .authenticationFailed:
            errorMessage = "Biometric authentication failed. Please try again"
        case .invalidContext:
            errorMessage = "Authentication context is invalid"
        case .notInteractive:
            errorMessage = "Authentication not interactive"
        case .passcodeNotSet:
            errorMessage = "Device passcode is not set"
        case .systemCancel:
            errorMessage = "Authentication was cancelled by the system"
        case .appCancel:
            errorMessage = "Authentication was cancelled by the app"
        case .invalidDimensions:
            errorMessage = "Invalid authentication dimensions"
#if os(watchOS)
        case .watchNotAvailable:
            errorMessage = "Apple Watch is not available for authentication"
#endif
        case .biometryDisconnected:
            errorMessage = "Biometric sensor is disconnected"
        case .touchIDNotAvailable:
            errorMessage = "Touch ID is not available on this device"
        case .touchIDNotEnrolled:
            errorMessage = "Touch ID is not set up. Please set up Touch ID in Settings"
        case .touchIDLockout:
            errorMessage = "Touch ID is locked. Please use device passcode"
        @unknown default:
            errorMessage = "Biometric authentication failed with unknown error"
        }
        
        print("❌ Biometric authentication error: \(errorMessage ?? "Unknown")")
    }
    
    // MARK: - Settings Management
    
    func enableBiometricAuth() async -> Bool {
        let success = await authenticateWithBiometrics(reason: "Enable \(biometricTypeString) for quick access to your account")
        
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
    
    // MARK: - Quick Authentication for App Launch
    
    func shouldRequireBiometricAuth() -> Bool {
        return isBiometricEnabled && isAvailable
    }
    
    func authenticateForAppAccess() async -> Bool {
        guard shouldRequireBiometricAuth() else {
            return true // No biometric auth required
        }
        
        return await authenticateWithBiometrics(reason: "Unlock Hamrah App with \(biometricTypeString)")
    }
}
