//
//  BiometricPromptView.swift
//  hamrahIOS
//
//  Biometric authentication prompt view for app launch
//

import SwiftUI

struct BiometricPromptView: View {
    @EnvironmentObject var biometricManager: BiometricAuthManager
    let onAuthenticated: () -> Void
    let onSkip: () -> Void
    
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo/Icon
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Hamrah")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // Biometric Authentication Section
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: biometricIconName)
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Unlock with \(biometricManager.biometricTypeString)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Use \(biometricManager.biometricTypeString) to securely access your account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    // Primary biometric authentication button
                    Button(action: authenticateWithBiometric) {
                        HStack {
                            if biometricManager.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: biometricIconName)
                            }
                            
                            Text(biometricManager.isAuthenticating ? "Authenticating..." : "Use \(biometricManager.biometricTypeString)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(biometricManager.isAuthenticating)
                    
                    // Skip/Enter app button
                    Button(action: onSkip) {
                        Text("Enter app without \(biometricManager.biometricTypeString)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .disabled(biometricManager.isAuthenticating)
                }
            }
            
            // Error message
            if let errorMessage = biometricManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .transition(.opacity)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("Secure access with biometric authentication")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your biometric data stays securely on your device")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .onAppear {
            // Automatically trigger biometric authentication when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticateWithBiometric()
            }
        }
    }
    
    private var biometricIconName: String {
        switch biometricManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock"
        @unknown default:
            return "questionmark"
        }
    }
    
    private func authenticateWithBiometric() {
        Task {
            let success = await biometricManager.authenticateForAppAccess()
            
            if success {
                onAuthenticated()
            }
            // If authentication fails, user can see the error and try again or skip
        }
    }
}

#Preview {
    BiometricPromptView(
        onAuthenticated: { print("Authenticated") },
        onSkip: { print("Skipped") }
    )
    .environmentObject(BiometricAuthManager())
}