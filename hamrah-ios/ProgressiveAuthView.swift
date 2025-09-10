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
    }
    
    private func checkBiometricAuthRequirement() {
        // Only require biometric auth if user is authenticated and biometric is enabled
        if authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth() {
            biometricAuthPending = true
        }
    }
    
    private func handleBiometricAuthOnLaunch() async {
        let success = await biometricManager.authenticateForAppAccess()
        
        await MainActor.run {
            biometricAuthPending = false
            
            if !success {
                // If biometric auth fails, log out the user
                authManager.logout()
            }
        }
    }
}

#Preview {
    ProgressiveAuthView()
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
}