//
//  ProgressiveAuthView.swift
//  hamrahIOS
//
//  Simple authentication view that shows login or content based on auth state
//

import SwiftUI

struct ProgressiveAuthView: View {
    @EnvironmentObject private var authManager: NativeAuthManager
    @EnvironmentObject private var biometricManager: BiometricAuthManager
    @State private var biometricAuthPending = false
    @State private var showingBiometricPrompt = false
    @State private var hasCheckedBiometric = false
    
    var body: some View {
        Group {
            if biometricAuthPending {
                BiometricLaunchView()
                    .environmentObject(biometricManager)
                    .onAppear {
                        Task {
                            await handleBiometricAuthOnLaunch()
                        }
                    }
            } else if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
            } else {
                NativeLoginView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
            }
        }
        .onAppear {
            checkBiometricAuthRequirement()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            // Reset biometric check when authentication state changes
            if newValue != oldValue {
                hasCheckedBiometric = false
                checkBiometricAuthRequirement()
            }
        }
    }
    
    private func checkBiometricAuthRequirement() {
        // Prevent multiple biometric auth attempts
        guard !hasCheckedBiometric && !biometricAuthPending else { return }
        
        // Only require biometric auth if user is authenticated and biometric is enabled
        if authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth() {
            biometricAuthPending = true
            hasCheckedBiometric = true
        } else {
            hasCheckedBiometric = true
        }
    }
    
    private func handleBiometricAuthOnLaunch() async {
        // Prevent multiple simultaneous auth attempts
        guard biometricAuthPending else { return }
        
        let success = await biometricManager.authenticateForAppAccess()
        
        await MainActor.run {
            biometricAuthPending = false
            
            if !success {
                // If biometric auth fails, log out the user for security
                authManager.logout()
                hasCheckedBiometric = false // Allow re-checking after logout
            }
        }
    }
}

#Preview {
    ProgressiveAuthView()
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
}