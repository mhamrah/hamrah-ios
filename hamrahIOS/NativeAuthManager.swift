//
//  NativeAuthManager.swift
//  hamrahIOS
//
//  Native authentication manager supporting Apple Sign-In, Google Sign-In, and Passkeys
//  Integrates with hamrah.app backend for user management
//

import Foundation
import AuthenticationServices
import GoogleSignIn
import SwiftUI

@MainActor
class NativeAuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: HamrahUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "https://hamrah.app" // Use production server
    private var accessToken: String?
    
    struct HamrahUser: Codable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
        let authMethod: String
        let createdAt: String
    }
    
    struct AuthResponse: Codable {
        let success: Bool
        let user: HamrahUser?
        let accessToken: String?
        let error: String?
    }
    
    struct WebAuthnBeginResponse: Codable {
        let success: Bool
        let options: PublicKeyCredentialRequestOptions?
        let error: String?
    }
    
    struct PublicKeyCredentialRequestOptions: Codable {
        let challenge: String
        let timeout: Int?
        let rpId: String
        let allowCredentials: [PublicKeyCredentialDescriptor]?
        let userVerification: String?
    }
    
    struct PublicKeyCredentialDescriptor: Codable {
        let type: String
        let id: String
        let transports: [String]?
    }
    
    override init() {
        super.init()
        loadStoredAuth()
        configureGoogleSignIn()
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🍎 Starting Apple Sign-In...")
            
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            
            authController.performRequests()
            
        } catch {
            errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
            print("❌ Apple Sign-In error: \(error)")
            isLoading = false
        }
    }
    
    // MARK: - Google Sign-In
    
    private func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ GoogleService-Info.plist not found or CLIENT_ID missing")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ Google Sign-In configured with client ID from GoogleService-Info.plist")
    }
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔍 Starting Google Sign-In...")
            
            guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token"])
            }
            
            // Send Google token to backend
            try await authenticateWithBackend(provider: "google", credential: idToken, additionalData: [
                "email": user.profile?.email ?? "",
                "name": user.profile?.name ?? "",
                "picture": user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
            ])
            
        } catch {
            errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
            print("❌ Google Sign-In error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Passkey Authentication
    
    func signInWithPasskey(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔐 Starting Passkey authentication for \(email)...")
            
            // Step 1: Begin WebAuthn authentication
            let beginOptions = try await beginWebAuthnAuthentication(email: email)
            
            guard let options = beginOptions.options else {
                throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authentication options received"])
            }
            
            // Step 2: Perform platform authentication
            let assertion = try await performPlatformAuthentication(options: options)
            
            // Step 3: Complete authentication with backend
            try await completeWebAuthnAuthentication(assertion: assertion, email: email)
            
        } catch {
            errorMessage = "Passkey authentication failed: \(error.localizedDescription)"
            print("❌ Passkey error: \(error)")
        }
        
        isLoading = false
    }
    
    private func beginWebAuthnAuthentication(email: String) async throws -> WebAuthnBeginResponse {
        let url = URL(string: "\(baseURL)/api/webauthn/authenticate/begin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(WebAuthnBeginResponse.self, from: data)
    }
    
    private func performPlatformAuthentication(options: PublicKeyCredentialRequestOptions) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        let challenge = Data(base64Encoded: options.challenge) ?? Data()
        
        let request = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: options.rpId)
            .createCredentialAssertionRequest(challenge: challenge)
        
        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            
            // Store continuation for delegate callback
            PasskeyAuthDelegate.shared.setContinuation(continuation)
            
            controller.delegate = PasskeyAuthDelegate.shared
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }
    
    private func completeWebAuthnAuthentication(assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion, email: String) async throws {
        let url = URL(string: "\(baseURL)/api/webauthn/authenticate/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body = [
            "email": email,
            "credentialId": assertion.credentialID.base64EncodedString(),
            "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
            "signature": assertion.signature.base64EncodedString(),
            "userHandle": assertion.userID?.base64EncodedString() ?? ""
        ]
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        if authResponse.success, let user = authResponse.user, let token = authResponse.accessToken {
            self.currentUser = user
            self.accessToken = token
            self.isAuthenticated = true
            self.storeAuthState()
            print("✅ Passkey authentication successful")
        } else {
            throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: authResponse.error ?? "Authentication failed"])
        }
    }
    
    // MARK: - Backend Integration
    
    private func authenticateWithBackend(provider: String, credential: String, additionalData: [String: String] = [:]) async throws {
        let url = URL(string: "\(baseURL)/api/auth/native")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        var body = [
            "provider": provider,
            "credential": credential
        ]
        
        // Add additional data
        for (key, value) in additionalData {
            body[key] = value
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend authentication failed"])
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        if authResponse.success, let user = authResponse.user, let token = authResponse.accessToken {
            self.currentUser = user
            self.accessToken = token
            self.isAuthenticated = true
            self.storeAuthState()
            print("✅ Backend authentication successful")
        } else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: authResponse.error ?? "Authentication failed"])
        }
    }
    
    // MARK: - Storage
    
    private func storeAuthState() {
        if let user = currentUser, let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "hamrah_user")
        }
        UserDefaults.standard.set(accessToken, forKey: "hamrah_access_token")
        UserDefaults.standard.set(isAuthenticated, forKey: "hamrah_is_authenticated")
    }
    
    private func loadStoredAuth() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "hamrah_is_authenticated")
        accessToken = UserDefaults.standard.string(forKey: "hamrah_access_token")
        
        if let userData = UserDefaults.standard.data(forKey: "hamrah_user"),
           let user = try? JSONDecoder().decode(HamrahUser.self, from: userData) {
            currentUser = user
        }
    }
    
    private func clearStoredAuth() {
        UserDefaults.standard.removeObject(forKey: "hamrah_user")
        UserDefaults.standard.removeObject(forKey: "hamrah_access_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_is_authenticated")
    }
    
    // MARK: - Logout
    
    func logout() {
        isAuthenticated = false
        currentUser = nil
        accessToken = nil
        clearStoredAuth()
        print("🚪 User logged out")
    }
}

// MARK: - Apple Sign-In Delegate

extension NativeAuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            do {
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    guard let identityToken = appleIDCredential.identityToken,
                          let tokenString = String(data: identityToken, encoding: .utf8) else {
                        throw NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No identity token"])
                    }
                    
                    let additionalData = [
                        "email": appleIDCredential.email ?? "",
                        "name": [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                    ]
                    
                    try await authenticateWithBackend(provider: "apple", credential: tokenString, additionalData: additionalData)
                }
            } catch {
                errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                print("❌ Apple Sign-In completion error: \(error)")
            }
            isLoading = false
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
        print("❌ Apple Sign-In error: \(error)")
        isLoading = false
    }
}

// MARK: - Presentation Context Provider

extension NativeAuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Passkey Auth Delegate

class PasskeyAuthDelegate: NSObject, ASAuthorizationControllerDelegate {
    static let shared = PasskeyAuthDelegate()
    
    private var continuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?
    
    func setContinuation(_ continuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>) {
        self.continuation = continuation
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let assertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            continuation?.resume(returning: assertion)
        } else {
            continuation?.resume(throwing: NSError(domain: "PasskeyAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid credential type"]))
        }
        continuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}