//
//  RootView.swift
//  hamrahIOS
//
//  Root view that handles authentication state and navigation
//

import SwiftUI

struct RootView: View {
    @StateObject private var nativeAuthManager = NativeAuthManager()
    @StateObject private var biometricManager = BiometricAuthManager()
    @State private var showBiometricPrompt = false
    @State private var biometricAuthComplete = false
    
    var body: some View {
        Group {
            if nativeAuthManager.isAuthenticated {
                if biometricManager.shouldRequireBiometricAuth() && !biometricAuthComplete {
                    BiometricPromptView(
                        onAuthenticated: {
                            biometricAuthComplete = true
                        },
                        onSkip: {
                            biometricAuthComplete = true
                        }
                    )
                    .environmentObject(biometricManager)
                } else {
                    ContentView()
                        .environmentObject(nativeAuthManager)
                        .environmentObject(biometricManager)
                }
            } else {
                NativeLoginView()
                    .environmentObject(nativeAuthManager)
                    .environmentObject(biometricManager)
            }
        }
        .onAppear {
            // Reset biometric auth state when returning to root
            if !nativeAuthManager.isAuthenticated {
                biometricAuthComplete = false
            }
        }
    }
}

#Preview {
    RootView()
}