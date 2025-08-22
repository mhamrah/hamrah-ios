//
//  AddPasskeyView.swift
//  hamrahIOS
//
//  Add Passkey view for iOS app
//

import SwiftUI
import AuthenticationServices

struct AddPasskeyView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: NativeAuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    let onPasskeyAdded: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "key.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                // Title and Description
                VStack(spacing: 16) {
                    Text("Add Passkey")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Passkeys provide secure, passwordless authentication using your device's biometrics or PIN.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Add Passkey Button
                Button(action: addPasskey) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        Text(isLoading ? "Creating..." : "Add Passkey")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
                
                // Cancel Button
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.secondary)
                .disabled(isLoading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Passkey")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }.disabled(isLoading))
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func addPasskey() {
        // Debug authentication state
        print("🔍 Authentication Debug:")
        print("  Current User: \(authManager.currentUser?.email ?? "nil")")
        print("  Access Token: \(authManager.accessToken != nil ? "present" : "nil")")
        print("  Is Authenticated: \(authManager.isAuthenticated)")
        
        guard let user = authManager.currentUser else {
            errorMessage = "No user found. Please sign in again."
            return
        }
        
        guard let accessToken = authManager.accessToken else {
            errorMessage = "No access token found. Please sign in again."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await registerPasskey(email: user.email, accessToken: accessToken)
                await MainActor.run {
                    self.isLoading = false
                    self.onPasskeyAdded()
                    self.presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add passkey: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func registerPasskey(email: String, accessToken: String) async throws {
        // Step 1: Begin WebAuthn registration
        let beginOptions = try await beginWebAuthnRegistration(email: email, accessToken: accessToken)
        
        guard let options = beginOptions.options else {
            throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No registration options received"])
        }
        
        let challengeId = options.challengeId
        
        // Step 2: Perform platform registration
        let attestation = try await performPlatformRegistration(options: options)
        
        // Step 3: Complete registration with backend
        try await completeWebAuthnRegistration(attestation: attestation, challengeId: challengeId, email: email, accessToken: accessToken)
    }
    
    private func beginWebAuthnRegistration(email: String, accessToken: String) async throws -> WebAuthnBeginRegistrationResponse {
        let url = URL(string: "\(authManager.baseURL)/api/webauthn/register/begin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body = [
            "email": email,
            "name": authManager.currentUser?.name ?? ""
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // Always try to decode the response to get the error message
        let apiResponse = try JSONDecoder().decode(WebAuthnBeginRegistrationResponse.self, from: data)
        
        if httpResponse.statusCode == 401 {
            // Clear stored auth on 401 to force re-authentication
            await MainActor.run {
                authManager.logout()
            }
            throw NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = apiResponse.error ?? "Failed to begin registration (HTTP \(httpResponse.statusCode))"
            throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        if !apiResponse.success {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Registration failed"])
        }
        
        return apiResponse
    }
    
    private func performPlatformRegistration(options: PublicKeyCredentialCreationOptions) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        let challenge = Data(base64Encoded: options.challenge) ?? Data()
        let userID = Data(base64Encoded: options.user.id) ?? Data()
        
        let request = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rp.id)
            .createCredentialRegistrationRequest(challenge: challenge, name: options.user.name, userID: userID)
        
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            
            // Store continuation for delegate callback
            PasskeyRegistrationDelegate.shared.setContinuation(continuation)
            
            controller.delegate = PasskeyRegistrationDelegate.shared
            controller.presentationContextProvider = authManager
            controller.performRequests()
        }
    }
    
    private func completeWebAuthnRegistration(attestation: ASAuthorizationPlatformPublicKeyCredentialRegistration, challengeId: String, email: String, accessToken: String) async throws {
        let url = URL(string: "\(authManager.baseURL)/api/webauthn/register/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        // Create the response object matching SimpleWebAuthn's RegistrationResponseJSON format
        let registrationResponseData = [
            "id": attestation.credentialID.base64EncodedString(),
            "rawId": attestation.credentialID.base64EncodedString(),
            "type": "public-key",
            "response": [
                "attestationObject": attestation.rawAttestationObject?.base64EncodedString() ?? "",
                "clientDataJSON": attestation.rawClientDataJSON.base64EncodedString()
            ]
        ] as [String: Any]
        
        let body = [
            "response": registrationResponseData,
            "challengeId": challengeId,
            "email": email,
            "name": authManager.currentUser?.name ?? ""
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        // Always try to decode the response to get the error message
        let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
        
        if httpResponse.statusCode == 401 {
            // Clear stored auth on 401 to force re-authentication
            await MainActor.run {
                authManager.logout()
            }
            throw NSError(domain: "API", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication expired. Please sign in again."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = apiResponse.error ?? "Registration failed (HTTP \(httpResponse.statusCode))"
            throw NSError(domain: "API", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        if !apiResponse.success {
            throw NSError(domain: "API", code: -1, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Registration failed"])
        }
    }
}

// MARK: - Data Models for Registration

struct WebAuthnBeginRegistrationResponse: Codable {
    let success: Bool
    let options: PublicKeyCredentialCreationOptions?
    let error: String?
}

struct PublicKeyCredentialCreationOptions: Codable {
    let challenge: String
    let rp: RelyingParty
    let user: UserInfo
    let pubKeyCredParams: [PubKeyCredParam]
    let timeout: Int?
    let excludeCredentials: [PublicKeyCredentialDescriptorForCreation]?
    let authenticatorSelection: AuthenticatorSelection?
    let challengeId: String
}

struct RelyingParty: Codable {
    let id: String
    let name: String
}

struct UserInfo: Codable {
    let id: String
    let name: String
    let displayName: String
}

struct PubKeyCredParam: Codable {
    let type: String
    let alg: Int
}

struct AuthenticatorSelection: Codable {
    let authenticatorAttachment: String?
    let userVerification: String?
    let requireResidentKey: Bool?
}

struct PublicKeyCredentialDescriptorForCreation: Codable {
    let type: String
    let id: String
    let transports: [String]?
}

// MARK: - Passkey Registration Delegate

class PasskeyRegistrationDelegate: NSObject, ASAuthorizationControllerDelegate {
    static let shared = PasskeyRegistrationDelegate()
    
    private var continuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>?
    
    func setContinuation(_ continuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let registration = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            continuation?.resume(returning: registration)
        } else {
            continuation?.resume(throwing: NSError(domain: "PasskeyRegistration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"]))
        }
        continuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

#Preview {
    AddPasskeyView(onPasskeyAdded: {})
        .environmentObject(NativeAuthManager())
}