//
//  MyAccountView.swift
//  hamrahIOS
//
//  My Account page for iOS app
//

import SwiftUI
import AuthenticationServices

struct MyAccountView: View {
    @EnvironmentObject var authManager: NativeAuthManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @State private var passkeys: [PasskeyCredential] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmDialog = false
    @State private var credentialToDelete: PasskeyCredential?
    @State private var showAddPasskey = false
    @State private var showBiometricSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // User Information Section
                    userInfoSection
                    
                    // Biometric Security Section
                    biometricSection
                    
                    // Passkeys Section
                    passkeysSection
                    
                    // Logout Section
                    logoutSection
                }
                .padding()
            }
            .navigationTitle("My Account")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                // Validate auth state and refresh if needed
                validateAuthState()
                loadPasskeys()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Remove Passkey", isPresented: $showConfirmDialog) {
                Button("Cancel", role: .cancel) {
                    credentialToDelete = nil
                }
                Button("Remove", role: .destructive) {
                    if let credential = credentialToDelete {
                        removePasskey(credential)
                    }
                }
            } message: {
                Text("Are you sure you want to remove this passkey? This action cannot be undone.")
            }
        }
    }
    
    private var userInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                if let user = authManager.currentUser {
                    AccountInfoRow(label: "User ID", value: user.id)
                    AccountInfoRow(label: "Email", value: user.email)
                    AccountInfoRow(label: "Name", value: user.name ?? "Not provided")
                    AccountInfoRow(label: "Auth Method", value: user.authMethod.capitalized)
                    AccountInfoRow(label: "Member Since", value: formatDate(user.createdAt))
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private var biometricSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                Button(action: {
                    showBiometricSettings = true
                }) {
                    HStack {
                        Image(systemName: biometricIconName)
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(biometricManager.biometricTypeString)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Text(biometricStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .buttonStyle(PlainButtonStyle())
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
            return "lock.slash"
        @unknown default:
            return "questionmark"
        }
    }
    
    private var biometricStatusText: String {
        if !biometricManager.isAvailable {
            return "Not available on this device"
        } else if biometricManager.isBiometricEnabled {
            return "Enabled"
        } else {
            return "Tap to set up"
        }
    }
    
    private var passkeysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Passkeys")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Passkey") {
                    showAddPasskey = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .disabled(isLoading || authManager.currentUser == nil || authManager.accessToken == nil)
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView("Loading passkeys...")
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if passkeys.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                    Text("No passkeys found")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Add a passkey for secure authentication")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                VStack(spacing: 8) {
                    ForEach(passkeys) { passkey in
                        PasskeyRow(
                            passkey: passkey,
                            onRemove: { credential in
                                credentialToDelete = credential
                                showConfirmDialog = true
                            }
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .sheet(isPresented: $showAddPasskey) {
            AddPasskeyView(onPasskeyAdded: {
                loadPasskeys()
            })
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showBiometricSettings) {
            NavigationView {
                BiometricSettingsView()
                    .environmentObject(biometricManager)
                    .navigationBarItems(trailing: Button("Done") {
                        showBiometricSettings = false
                    })
            }
        }
    }
    
    private var logoutSection: some View {
        VStack {
            Button("Sign Out") {
                authManager.logout()
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    private func validateAuthState() {
        // Check if we have the required auth components
        if authManager.isAuthenticated && (authManager.currentUser == nil || authManager.accessToken == nil) {
            print("⚠️ Invalid auth state detected - isAuthenticated=true but missing user or token")
            authManager.logout()
            errorMessage = "Authentication state invalid. Please sign in again."
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
    
    private func loadPasskeys() {
        // Debug authentication state
        print("🔍 MyAccountView Authentication Debug:")
        print("  Current User: \(authManager.currentUser?.email ?? "nil")")
        print("  Access Token: \(authManager.accessToken != nil ? "present" : "nil")")
        print("  Is Authenticated: \(authManager.isAuthenticated)")
        
        guard let accessToken = authManager.accessToken else { 
            errorMessage = "Not authenticated. Please sign in again."
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let credentials = try await fetchPasskeys(accessToken: accessToken)
                await MainActor.run {
                    self.passkeys = credentials
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load passkeys: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func removePasskey(_ credential: PasskeyCredential) {
        guard let accessToken = authManager.accessToken else { return }
        
        Task {
            do {
                try await deletePasskey(credentialId: credential.id, accessToken: accessToken)
                await MainActor.run {
                    self.passkeys.removeAll { $0.id == credential.id }
                    self.credentialToDelete = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to remove passkey: \(error.localizedDescription)"
                    self.credentialToDelete = nil
                }
            }
        }
    }
    
    private func fetchPasskeys(accessToken: String) async throws -> [PasskeyCredential] {
        let url = URL(string: "\(authManager.baseURL)/api/webauthn/credentials")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // Always try to decode the response to get the error message
        let apiResponse = try JSONDecoder().decode(PasskeyListResponse.self, from: data)
        
        if httpResponse.statusCode == 401 {
            throw NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = apiResponse.error ?? "Failed to fetch passkeys (HTTP \(httpResponse.statusCode))"
            throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        if apiResponse.success {
            return apiResponse.credentials
        } else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Unknown error"])
        }
    }
    
    private func deletePasskey(credentialId: String, accessToken: String) async throws {
        let url = URL(string: "\(authManager.baseURL)/api/webauthn/credentials")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body = ["credentialId": credentialId]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to delete passkey"])
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if !apiResponse.success {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Unknown error"])
        }
    }
}

struct AccountInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

struct PasskeyRow: View {
    let passkey: PasskeyCredential
    let onRemove: (PasskeyCredential) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text(passkey.name)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Text("Created \(formatDate(passkey.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if let lastUsed = passkey.lastUsed {
                    Text("Last used \(formatDate(lastUsed))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Remove") {
                onRemove(passkey)
            }
            .font(.caption2)
            .foregroundColor(.red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
            .cornerRadius(6)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Data Models

struct PasskeyCredential: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: String
    let lastUsed: String?
    let credentialDeviceType: String?
    let credentialBackedUp: Bool?
}

struct PasskeyListResponse: Codable {
    let success: Bool
    let credentials: [PasskeyCredential]
    let error: String?
}

struct APIResponse: Codable {
    let success: Bool
    let error: String?
    let message: String?
}

#Preview {
    MyAccountView()
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
}