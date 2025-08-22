//
//  ProgressiveAuthManager.swift
//  hamrahIOS
//
//  Progressive authentication manager that handles:
//  1. Token validation and refresh
//  2. Biometric authentication
//  3. Automatic passkey login
//  4. Fallback to manual login
//

import Foundation
import SwiftUI

enum AuthenticationState {
    case checking          // Initial state, checking stored credentials
    case validToken        // Valid token found, user is authenticated
    case refreshingToken   // Token expired, attempting to refresh
    case biometricRequired // Token refresh failed, requiring biometric auth
    case passkeyAvailable  // Biometric failed/unavailable, passkey auto-login available
    case manualLogin       // All automatic methods failed, show manual login
    case authenticated     // Successfully authenticated through any method
    case failed           // Authentication failed completely
}

@MainActor
class ProgressiveAuthManager: ObservableObject {
    @Published var currentState: AuthenticationState = .checking
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authManager: NativeAuthManager
    private let biometricManager: BiometricAuthManager
    
    init(authManager: NativeAuthManager, biometricManager: BiometricAuthManager) {
        self.authManager = authManager
        self.biometricManager = biometricManager
    }
    
    // MARK: - Progressive Authentication Flow
    
    func startProgressiveAuth() async {
        await MainActor.run {
            currentState = .checking
            isLoading = true
            errorMessage = nil
        }
        
        print("🔄 Starting progressive authentication flow...")
        
        // Step 1: Check if we have a valid token
        if authManager.isAuthenticated && authManager.accessToken != nil {
            if authManager.isTokenExpiringSoon() {
                await attemptTokenRefresh()
            } else {
                await completeAuthentication()
                return
            }
        } else {
            // No stored auth, start progressive login
            await attemptProgressiveLogin()
        }
    }
    
    // MARK: - Token Management
    
    private func attemptTokenRefresh() async {
        await MainActor.run {
            currentState = .refreshingToken
        }
        
        print("🔄 Attempting token refresh...")
        
        let refreshSuccess = await authManager.refreshToken()
        if refreshSuccess {
            await completeAuthentication()
        } else {
            // Token refresh failed, try biometric auth
            await attemptBiometricAuth()
        }
    }
    
    // MARK: - Biometric Authentication
    
    private func attemptBiometricAuth() async {
        guard biometricManager.shouldRequireBiometricAuth() else {
            // Biometric not enabled/available, try passkey
            await attemptPasskeyAutoLogin()
            return
        }
        
        await MainActor.run {
            currentState = .biometricRequired
        }
        
        print("🔐 Attempting biometric authentication...")
        
        let biometricSuccess = await biometricManager.authenticateForAppAccess()
        if biometricSuccess {
            // Biometric auth successful, but we still need a valid token
            // Try to get user to re-authenticate with stored credentials
            await attemptPasskeyAutoLogin()
        } else {
            // Biometric failed, try passkey
            await attemptPasskeyAutoLogin()
        }
    }
    
    // MARK: - Automatic Passkey Login
    
    private func attemptPasskeyAutoLogin() async {
        guard let lastEmail = authManager.getLastUsedEmail() else {
            // No stored email, fallback to manual login
            await showManualLogin()
            return
        }
        
        await MainActor.run {
            currentState = .passkeyAvailable
        }
        
        print("🔑 Attempting automatic passkey login with email: \(lastEmail)")
        
        // Check if user has passkeys registered
        let hasPasskeys = await authManager.checkPasskeyAvailability()
        guard hasPasskeys else {
            // No passkeys available, fallback to manual login
            await showManualLogin()
            return
        }
        
        // Attempt automatic passkey authentication
        await authManager.signInWithPasskey(email: lastEmail)
        
        if authManager.isAuthenticated {
            await completeAuthentication()
        } else {
            // Passkey auth failed, fallback to manual login
            await showManualLogin()
        }
    }
    
    // MARK: - Progressive Login Flow
    
    private func attemptProgressiveLogin() async {
        // First try biometric if enabled
        if biometricManager.shouldRequireBiometricAuth() {
            await attemptBiometricAuth()
        } else {
            // No biometric, try passkey auto-login
            await attemptPasskeyAutoLogin()
        }
    }
    
    // MARK: - Completion States
    
    func completeAuthentication() async {
        await MainActor.run {
            currentState = .authenticated
            isLoading = false
            errorMessage = nil
        }
        
        print("✅ Progressive authentication completed successfully")
    }
    
    func showManualLogin() async {
        await MainActor.run {
            currentState = .manualLogin
            isLoading = false
        }
        
        print("📋 Falling back to manual login")
    }
    
    func authenticationFailed(error: String) async {
        await MainActor.run {
            currentState = .failed
            isLoading = false
            errorMessage = error
        }
        
        print("❌ Progressive authentication failed: \(error)")
    }
    
    // MARK: - Manual Override Methods
    
    func skipToManualLogin() async {
        await showManualLogin()
    }
    
    func retryProgressiveAuth() async {
        await startProgressiveAuth()
    }
    
    // MARK: - State Helpers
    
    var shouldShowManualLogin: Bool {
        return currentState == .manualLogin || currentState == .failed
    }
    
    var isProgressiveAuthComplete: Bool {
        return currentState == .authenticated
    }
    
    var shouldShowBiometricPrompt: Bool {
        return currentState == .biometricRequired
    }
    
    var shouldShowPasskeyPrompt: Bool {
        return currentState == .passkeyAvailable
    }
    
    // MARK: - Logout Handling
    
    func handleLogout() async {
        await MainActor.run {
            currentState = .checking
            isLoading = false
            errorMessage = nil
        }
        
        print("🚪 User logged out, resetting progressive auth state")
        
        // Start progressive auth flow again to determine the appropriate login method
        await startProgressiveAuth()
    }
}