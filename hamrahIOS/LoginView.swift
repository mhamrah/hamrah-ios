//
//  LoginView.swift
//  hamrahIOS
//
//  Login view for OAuth authentication
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Hamrah")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Login Button
            Button(action: {
                Task {
                    await authManager.login()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                    }
                    
                    Text(authManager.isLoading ? "Signing In..." : "Sign In with Hamrah")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading)
            
            // Error Message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Footer
            Text("Secure authentication via hamrah.app")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}