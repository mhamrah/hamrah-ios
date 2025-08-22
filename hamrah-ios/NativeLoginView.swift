//
//  NativeLoginView.swift
//  hamrahIOS
//
//  Native login interface with Apple Sign-In, Google Sign-In, and Passkeys
//

import SwiftUI
import AuthenticationServices

struct NativeLoginView: View {
    @EnvironmentObject var authManager: NativeAuthManager
    @State private var email = ""
    @State private var showingPasskeyLogin = false
    @State private var showingEmailInput = false
    @State private var hasPasskeysAvailable = false
    @State private var checkedPasskeyAvailability = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // App Logo/Title
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                
                Text("Welcome to Hamrah")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Authentication Methods
            VStack(spacing: 16) {
                
                // Automatic Passkey Sign-In (shown only if passkeys available)
                if hasPasskeysAvailable {
                    Button(action: {
                        Task {
                            await authManager.signInWithPasskeyAutomatic()
                        }
                    }) {
                        HStack {
                            Image(systemName: "faceid")
                                .foregroundColor(.white)
                            Text("Sign in with Passkey")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                    .disabled(authManager.isLoading)
                }
                
                // Apple Sign-In
                Button(action: {
                    Task {
                        await authManager.signInWithApple()
                    }
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                            .foregroundColor(.white)
                        Text("Sign in with Apple")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(8)
                }
                .disabled(authManager.isLoading)
                
                // Google Sign-In
                Button(action: {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.white)
                        Text("Continue with Google")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(authManager.isLoading)
                
                // Manual Passkey Sign-In (shown only if no automatic passkeys available)
                if !hasPasskeysAvailable && checkedPasskeyAvailability {
                    Button(action: {
                        showingEmailInput = true
                    }) {
                        HStack {
                            Image(systemName: "key")
                                .foregroundColor(.white)
                            Text("Sign in with Email + Passkey")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                    .disabled(authManager.isLoading)
                }
            }
            
            // Loading Indicator
            if authManager.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Signing in...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
            }
            
            // Error Message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            Spacer()
            
            // Footer
            VStack(spacing: 8) {
                Text("Secure authentication")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Your data is protected and synced across devices")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .sheet(isPresented: $showingEmailInput) {
            PasskeyEmailInputView { email in
                Task {
                    await authManager.signInWithPasskey(email: email)
                }
                showingEmailInput = false
            }
        }
        .onAppear {
            if !checkedPasskeyAvailability {
                Task {
                    hasPasskeysAvailable = await authManager.checkPasskeyAvailability()
                    checkedPasskeyAvailability = true
                    
                    print("🔍 Passkey availability check: \(hasPasskeysAvailable)")
                }
            }
        }
    }
}

struct PasskeyEmailInputView: View {
    @State private var email = ""
    @Environment(\.presentationMode) var presentationMode
    let onContinue: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "faceid")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("Sign in with Passkey")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your email to use your saved passkey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    TextField("Email address", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("Continue with Passkey") {
                        onContinue(email)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(email.isEmpty ? Color.gray : Color.purple)
                    .cornerRadius(8)
                    .disabled(email.isEmpty)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Passkey Sign-In")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    NativeLoginView()
        .environmentObject(NativeAuthManager())
}