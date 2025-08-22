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
    
    let baseURL = "https://hamrah.app" // Use production server
    @Published var accessToken: String?
    
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
        let refreshToken: String?
        let expiresIn: Int?
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
        let challengeId: String
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
    
    func checkPasskeyAvailability() async -> Bool {
        // For now, let's check if the user has stored passkeys by checking the credentials endpoint
        // This is more reliable than trying to use the platform API
        guard let token = accessToken else { 
            print("🔍 No access token available for passkey check")
            return false 
        }
        
        let url = URL(string: "\(baseURL)/api/webauthn/credentials")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔍 Passkey availability check failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            // Parse response as simple JSON first
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = jsonObject["success"] as? Bool,
               success,
               let credentials = jsonObject["credentials"] as? [[String: Any]] {
                let hasPasskeys = !credentials.isEmpty
                print("🔍 Passkey availability check: \(hasPasskeys ? "has passkeys (\(credentials.count))" : "no passkeys")")
                return hasPasskeys
            }
            
            print("🔍 Passkey availability check: no passkeys (invalid response)")
            return false
            
        } catch {
            print("🔍 Passkey availability check error: \(error)")
            return false
        }
    }
    
    func signInWithPasskeyAutomatic() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔐 Starting automatic Passkey authentication...")
            
            // Step 1: Begin WebAuthn authentication without email (for resident keys)
            let beginOptions = try await beginWebAuthnAuthentication(email: nil)
            
            guard let options = beginOptions.options else {
                throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authentication options received"])
            }
            
            let challengeId = options.challengeId
            
            // Step 2: Perform platform authentication
            let assertion = try await performPlatformAuthentication(options: options)
            
            // Step 3: Complete authentication with backend
            try await completeWebAuthnAuthentication(assertion: assertion, challengeId: challengeId)
            
        } catch {
            errorMessage = "Passkey authentication failed: \(error.localizedDescription)"
            print("❌ Automatic Passkey error: \(error)")
        }
        
        isLoading = false
    }
    
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
            
            let challengeId = options.challengeId
            
            // Step 2: Perform platform authentication
            let assertion = try await performPlatformAuthentication(options: options)
            
            // Step 3: Complete authentication with backend
            try await completeWebAuthnAuthentication(assertion: assertion, challengeId: challengeId)
            
        } catch {
            errorMessage = "Passkey authentication failed: \(error.localizedDescription)"
            print("❌ Passkey error: \(error)")
        }
        
        isLoading = false
    }
    
    private func beginWebAuthnAuthentication(email: String?) async throws -> WebAuthnBeginResponse {
        let url = URL(string: "\(baseURL)/api/webauthn/authenticate/begin")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body: [String: Any]
        if let email = email {
            body = ["email": email]
        } else {
            body = [:]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
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
    
    
    private func completeWebAuthnAuthentication(assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion, challengeId: String) async throws {
        let url = URL(string: "\(baseURL)/api/webauthn/authenticate/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        // Create the response object matching SimpleWebAuthn's AuthenticationResponseJSON format
        let authResponseData = [
            "id": assertion.credentialID.base64EncodedString(),
            "rawId": assertion.credentialID.base64EncodedString(),
            "type": "public-key",
            "response": [
                "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                "signature": assertion.signature.base64EncodedString(),
                "userHandle": assertion.userID?.base64EncodedString() ?? ""
            ]
        ] as [String: Any]
        
        let body = [
            "response": authResponseData,
            "challengeId": challengeId
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
        }
        
        // Define a response structure that matches the server response
        struct PasskeyAuthResponse: Codable {
            let success: Bool
            let message: String?
            let user: HamrahUser?
            let error: String?
        }
        
        let authResponse = try JSONDecoder().decode(PasskeyAuthResponse.self, from: data)
        
        if authResponse.success, let user = authResponse.user {
            // Extract session token from Set-Cookie header
            if let setCookieHeader = httpResponse.value(forHTTPHeaderField: "Set-Cookie"),
               let sessionToken = extractSessionToken(from: setCookieHeader) {
                self.currentUser = user
                self.accessToken = sessionToken
                self.isAuthenticated = true
                
                // Store the email for future automatic passkey login
                self.setLastUsedEmail(user.email)
                
                self.storeAuthState()
                print("✅ Passkey authentication successful")
            } else {
                throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session token received"])
            }
        } else {
            throw NSError(domain: "WebAuthn", code: -1, userInfo: [NSLocalizedDescriptionKey: authResponse.error ?? "Authentication failed"])
        }
    }
    
    // MARK: - Session Token Extraction
    
    private func extractSessionToken(from setCookieHeader: String) -> String? {
        // Look for the session token cookie in the Set-Cookie header
        // Format: "session=token_value; Path=/; HttpOnly; Secure; SameSite=Lax"
        let components = setCookieHeader.components(separatedBy: ";")
        for component in components {
            let cookiePart = component.trimmingCharacters(in: .whitespaces)
            if cookiePart.hasPrefix("session=") {
                return String(cookiePart.dropFirst("session=".count))
            }
        }
        return nil
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
            
            // Store refresh token if provided
            if let refreshToken = authResponse.refreshToken {
                UserDefaults.standard.set(refreshToken, forKey: "hamrah_refresh_token")
            }
            
            // Store token expiration if provided
            if let expiresIn = authResponse.expiresIn {
                let expiresAt = Date().timeIntervalSince1970 + TimeInterval(expiresIn)
                UserDefaults.standard.set(expiresAt, forKey: "hamrah_token_expires_at")
            }
            
            // Store the user's email for future automatic login
            self.setLastUsedEmail(user.email)
            
            self.storeAuthState()
            print("✅ Backend authentication successful")
        } else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: authResponse.error ?? "Authentication failed"])
        }
    }
    
    // MARK: - Token Validation
    
    func validateAccessToken() async -> Bool {
        guard let token = accessToken else { return false }
        
        // Try to validate with a backend endpoint that we know exists
        let url = URL(string: "\(baseURL)/api/webauthn/credentials")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            
            if httpResponse.statusCode == 200 {
                // Token is valid
                print("🔍 Token validation successful")
                return true
            } else if httpResponse.statusCode == 401 {
                // Token is invalid/expired
                print("🔍 Token validation failed: token expired (401)")
                await MainActor.run {
                    logout()
                }
                return false
            } else {
                // Other errors - assume token is still valid but endpoint might have issues
                print("🔍 Token validation inconclusive with status: \(httpResponse.statusCode), assuming valid")
                return true
            }
        } catch {
            print("🔍 Token validation error: \(error), assuming valid")
            // If we can't validate due to network issues, assume token is valid
            return true
        }
    }
    
    // MARK: - Token Refresh
    
    func refreshToken() async -> Bool {
        guard let refreshToken = UserDefaults.standard.string(forKey: "hamrah_refresh_token") else {
            print("🔄 No refresh token available")
            return false
        }
        
        let url = URL(string: "\(baseURL)/api/auth/token/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("hamrah-ios", forHTTPHeaderField: "X-Requested-With")
        
        let body = ["refresh_token": refreshToken]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("🔄 Token refresh failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return false
            }
            
            struct TokenRefreshResponse: Codable {
                let access_token: String
                let refresh_token: String
                let expires_in: Int
            }
            
            let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
            
            // Update stored tokens
            await MainActor.run {
                self.accessToken = tokenResponse.access_token
                UserDefaults.standard.set(tokenResponse.access_token, forKey: "hamrah_access_token")
                UserDefaults.standard.set(tokenResponse.refresh_token, forKey: "hamrah_refresh_token")
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hamrah_auth_timestamp")
                UserDefaults.standard.set(Date().timeIntervalSince1970 + TimeInterval(tokenResponse.expires_in), forKey: "hamrah_token_expires_at")
            }
            
            print("✅ Token refreshed successfully")
            return true
            
        } catch {
            print("❌ Token refresh error: \(error)")
            return false
        }
    }
    
    func isTokenExpiringSoon() -> Bool {
        let expiresAt = UserDefaults.standard.double(forKey: "hamrah_token_expires_at")
        guard expiresAt > 0 else { return true }
        
        let fiveMinutesFromNow = Date().timeIntervalSince1970 + (5 * 60) // 5 minutes
        return expiresAt < fiveMinutesFromNow
    }
    
    // MARK: - Storage
    
    private func storeAuthState() {
        if let user = currentUser, let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "hamrah_user")
        }
        UserDefaults.standard.set(accessToken, forKey: "hamrah_access_token")
        UserDefaults.standard.set(isAuthenticated, forKey: "hamrah_is_authenticated")
        
        // Store timestamp for token validation
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hamrah_auth_timestamp")
    }
    
    private func loadStoredAuth() {
        isAuthenticated = UserDefaults.standard.bool(forKey: "hamrah_is_authenticated")
        accessToken = UserDefaults.standard.string(forKey: "hamrah_access_token")
        
        if let userData = UserDefaults.standard.data(forKey: "hamrah_user"),
           let user = try? JSONDecoder().decode(HamrahUser.self, from: userData) {
            currentUser = user
        }
        
        // Check if token is stale (older than 24 hours)
        let authTimestamp = UserDefaults.standard.double(forKey: "hamrah_auth_timestamp")
        let dayAgo = Date().timeIntervalSince1970 - (24 * 60 * 60) // 24 hours
        
        if authTimestamp > 0 && authTimestamp < dayAgo {
            print("🔍 Auth token is stale (older than 24 hours), clearing auth state")
            clearStoredAuth()
            isAuthenticated = false
            currentUser = nil
            accessToken = nil
        }
        
        // Debug loaded auth state
        print("🔍 Loaded Auth State:")
        print("  Is Authenticated: \(isAuthenticated)")
        print("  Access Token: \(accessToken != nil ? "present" : "nil")")
        print("  Current User: \(currentUser?.email ?? "nil")")
        if authTimestamp > 0 {
            print("  Auth Timestamp: \(Date(timeIntervalSince1970: authTimestamp))")
        } else {
            print("  Auth Timestamp: none")
        }
    }
    
    private func clearStoredAuth() {
        UserDefaults.standard.removeObject(forKey: "hamrah_user")
        UserDefaults.standard.removeObject(forKey: "hamrah_access_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_refresh_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_is_authenticated")
        UserDefaults.standard.removeObject(forKey: "hamrah_auth_timestamp")
        UserDefaults.standard.removeObject(forKey: "hamrah_token_expires_at")
        // Don't clear last used email for passkey auto-login
    }
    
    // MARK: - Last Used Email for Passkey Auto-Login
    
    func getLastUsedEmail() -> String? {
        return UserDefaults.standard.string(forKey: "hamrah_last_email")
    }
    
    func setLastUsedEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: "hamrah_last_email")
    }
    
    func clearLastUsedEmail() {
        UserDefaults.standard.removeObject(forKey: "hamrah_last_email")
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

// MARK: - Passkey Availability Delegate

class PasskeyAvailabilityDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let completion: (Bool) -> Void
    private var hasCompleted = false
    
    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func timeoutIfNeeded(timeoutCompletion: () -> Void) {
        if !hasCompleted {
            hasCompleted = true
            timeoutCompletion()
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasCompleted else { return }
        hasCompleted = true
        // If we get here, passkeys are available
        completion(true)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        // Check if error indicates no passkeys are available
        if let asError = error as? ASAuthorizationError {
            switch asError.code {
            case .notHandled, .notInteractive:
                completion(false)
            default:
                completion(true) // Other errors might still mean passkeys are available
            }
        } else {
            completion(false)
        }
    }
}