//
//  ProgressiveAuthView.swift
//  hamrahIOS
//
//  Progressive authentication view that handles the entire auth flow
//

import SwiftUI

struct ProgressiveAuthView: View {
    @StateObject private var progressiveAuth: ProgressiveAuthManager
    @EnvironmentObject private var authManager: NativeAuthManager
    @EnvironmentObject private var biometricManager: BiometricAuthManager
    
    init(authManager: NativeAuthManager, biometricManager: BiometricAuthManager) {
        self._progressiveAuth = StateObject(wrappedValue: ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        ))
    }
    
    var body: some View {
        Group {
            switch progressiveAuth.currentState {
            case .checking, .refreshingToken:
                LoadingView(message: progressiveAuth.currentState == .checking ? "Checking authentication..." : "Refreshing session...")
                    .onAppear {
                        print("🔍 UI: Showing LoadingView - state: \(progressiveAuth.currentState)")
                    }
                
            case .biometricRequired:
                BiometricAuthPromptView(progressiveAuth: progressiveAuth)
                    .onAppear {
                        print("🔍 UI: Showing BiometricAuthPromptView")
                    }
                
            case .passkeyAvailable:
                PasskeyAutoLoginView(progressiveAuth: progressiveAuth)
                    .onAppear {
                        print("🔍 UI: Showing PasskeyAutoLoginView")
                    }
                
            case .manualLogin, .failed:
                NativeLoginView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
                    .onAppear {
                        print("🔍 UI: Showing NativeLoginView - state: \(progressiveAuth.currentState)")
                    }
                
            case .authenticated, .validToken:
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(biometricManager)
                    .onAppear {
                        print("🔍 UI: Showing ContentView - state: \(progressiveAuth.currentState)")
                        print("🔍 UI: authManager.isAuthenticated = \(authManager.isAuthenticated)")
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            // Debug overlay - remove this in production
            VStack(alignment: .trailing, spacing: 4) {
                Text("State: \(String(describing: progressiveAuth.currentState))")
                Text("Auth: \(authManager.isAuthenticated ? "✅" : "❌")")
                Text("Complete: \(progressiveAuth.isProgressiveAuthComplete ? "✅" : "❌")")
            }
            .font(.caption)
            .padding(8)
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
        }
        .onAppear {
            Task {
                await progressiveAuth.startProgressiveAuth()
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            print("🔍 ProgressiveAuthView: authManager.isAuthenticated changed to \(isAuthenticated)")
            print("🔍 ProgressiveAuthView: progressiveAuth.currentState = \(progressiveAuth.currentState)")
            print("🔍 ProgressiveAuthView: progressiveAuth.isProgressiveAuthComplete = \(progressiveAuth.isProgressiveAuthComplete)")
            
            if isAuthenticated && !progressiveAuth.isProgressiveAuthComplete {
                print("🔍 ProgressiveAuthView: Calling completeAuthentication()")
                Task {
                    await progressiveAuth.completeAuthentication()
                }
            } else if !isAuthenticated {
                print("🔍 ProgressiveAuthView: User logged out, calling handleLogout()")
                // User logged out, handle logout properly
                Task {
                    await progressiveAuth.handleLogout()
                }
            } else if isAuthenticated && progressiveAuth.isProgressiveAuthComplete {
                print("🔍 ProgressiveAuthView: Already authenticated and complete")
            }
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Biometric Auth Prompt View

struct BiometricAuthPromptView: View {
    @EnvironmentObject private var biometricManager: BiometricAuthManager
    let progressiveAuth: ProgressiveAuthManager
    
    init(progressiveAuth: ProgressiveAuthManager) {
        self.progressiveAuth = progressiveAuth
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Biometric Icon
            Image(systemName: biometricManager.biometricType == .faceID ? "faceid" : "touchid")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 16) {
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Use \(biometricManager.biometricTypeString) to securely access your account")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        await attemptBiometricAuth()
                    }
                }) {
                    HStack {
                        Image(systemName: biometricManager.biometricType == .faceID ? "faceid" : "touchid")
                        Text("Authenticate with \(biometricManager.biometricTypeString)")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(biometricManager.isAuthenticating)
                
                Button("Use Other Sign In Options") {
                    Task {
                        await progressiveAuth.skipToManualLogin()
                    }
                }
                .font(.body)
                .foregroundColor(.blue)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
    
    private func attemptBiometricAuth() async {
        let success = await biometricManager.authenticateForAppAccess()
        if success {
            // Biometric auth successful - complete authentication if user has valid token
            // or proceed to next auth method if token needs refresh
            Task {
                await progressiveAuth.handleSuccessfulBiometricAuth()
            }
        } else {
            // Skip to next auth method
            Task {
                await progressiveAuth.skipToManualLogin()
            }
        }
    }
}

// MARK: - Passkey Auto Login View

struct PasskeyAutoLoginView: View {
    @EnvironmentObject private var authManager: NativeAuthManager
    let progressiveAuth: ProgressiveAuthManager
    
    init(progressiveAuth: ProgressiveAuthManager) {
        self.progressiveAuth = progressiveAuth
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Passkey Icon
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            VStack(spacing: 16) {
                Text("Quick Sign In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if let lastEmail = authManager.getLastUsedEmail() {
                    Text("Sign in automatically with your passkey for \(lastEmail)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("Sign in automatically with your passkey")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        await attemptPasskeyLogin()
                    }
                }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Sign In with Passkey")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .disabled(authManager.isLoading)
                
                Button("Use Other Sign In Options") {
                    Task {
                        await progressiveAuth.skipToManualLogin()
                    }
                }
                .font(.body)
                .foregroundColor(.purple)
            }
            .padding(.horizontal)
            .padding(.bottom, 50)
        }
        .background(Color(.systemBackground))
    }
    
    private func attemptPasskeyLogin() async {
        guard let lastEmail = authManager.getLastUsedEmail() else {
            await progressiveAuth.skipToManualLogin()
            return
        }
        
        await authManager.signInWithPasskey(email: lastEmail)
        
        if !authManager.isAuthenticated {
            // Passkey auth failed, fallback to manual login
            await progressiveAuth.skipToManualLogin()
        }
    }
}

#Preview {
    ProgressiveAuthView(
        authManager: NativeAuthManager(),
        biometricManager: BiometricAuthManager()
    )
}