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
    
    let baseURL = "https://api.hamrah.app" // Use production API server
    @Published var accessToken: String?
    
    // Secure API service with App Attestation
    private let secureAPI = SecureAPIService.shared
    
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
        
        // Handle different possible field names for access token
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            success = try container.decode(Bool.self, forKey: DynamicCodingKeys(stringValue: "success")!)
            user = try container.decodeIfPresent(HamrahUser.self, forKey: DynamicCodingKeys(stringValue: "user")!)
            error = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "error")!)
            refreshToken = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "refreshToken")!)
            expiresIn = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "expiresIn")!)
            
            // Try different possible field names for access token
            var tempAccessToken = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "accessToken")!)
            if tempAccessToken == nil {
                tempAccessToken = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "access_token")!)
            }
            if tempAccessToken == nil {
                tempAccessToken = try container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "token")!)
            }
            accessToken = tempAccessToken
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            try container.encode(success, forKey: DynamicCodingKeys(stringValue: "success")!)
            try container.encodeIfPresent(user, forKey: DynamicCodingKeys(stringValue: "user")!)
            try container.encodeIfPresent(accessToken, forKey: DynamicCodingKeys(stringValue: "accessToken")!)
            try container.encodeIfPresent(refreshToken, forKey: DynamicCodingKeys(stringValue: "refreshToken")!)
            try container.encodeIfPresent(expiresIn, forKey: DynamicCodingKeys(stringValue: "expiresIn")!)
            try container.encodeIfPresent(error, forKey: DynamicCodingKeys(stringValue: "error")!)
        }
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
        
        print("🍎 Starting Apple Sign-In...")
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.presentationContextProvider = self
        
        authController.performRequests()
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
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let presentingViewController = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            let user = result.user
            
            print("🔍 Google Sign-In result received:")
            print("  User ID: \(user.userID ?? "nil")")
            print("  Email: \(user.profile?.email ?? "nil")")
            print("  Name: \(user.profile?.name ?? "nil")")
            
            guard let idToken = user.idToken?.tokenString else {
                throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No ID token"])
            }
            
            print("🔍 Google ID token received, length: \(idToken.count)")
            print("🔍 Sending authentication request to backend...")
            
            // Send Google token to backend
            try await authenticateWithBackend(provider: "google", credential: idToken, additionalData: [
                "email": user.profile?.email ?? "",
                "name": user.profile?.name ?? "",
                "picture": user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
            ])
            
            print("🔍 Google backend authentication completed successfully")
            
        } catch {
            errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
            print("❌ Google Sign-In error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Passkey Authentication
    
    func checkPasskeyAvailability() async -> Bool {
        guard let token = accessToken else { 
            print("🔍 No access token available for passkey check")
            return false 
        }
        
        do {
            struct PasskeyCredentialsResponse: Codable {
                let success: Bool
                let credentials: [PasskeyCredentialInfo]
                let error: String?
            }
            
            struct PasskeyCredentialInfo: Codable {
                let id: String
                let name: String?
            }
            
            let response = try await secureAPI.get(
                endpoint: "/api/webauthn/credentials",
                accessToken: token,
                responseType: PasskeyCredentialsResponse.self
            )
            
            let hasPasskeys = response.success && !response.credentials.isEmpty
            print("🔍 Passkey availability check: \(hasPasskeys ? "has passkeys (\(response.credentials.count))" : "no passkeys")")
            return hasPasskeys
            
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
        let body: [String: Any]
        if let email = email {
            body = ["email": email]
        } else {
            body = [:]
        }
        
        return try await secureAPI.post(
            endpoint: "/api/webauthn/authenticate/begin",
            body: body,
            accessToken: nil, // No auth needed for begin authentication
            responseType: WebAuthnBeginResponse.self
        )
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
        
        // Note: This method needs to handle Set-Cookie headers manually since SecureAPI doesn't support it yet
        // TODO: Update SecureAPI to support cookie handling for this specific case
        let url = URL(string: "\(baseURL)/api/webauthn/authenticate/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add App Attestation headers (required)
        let challenge = generateRequestChallenge(url: url, method: "POST", body: body)
        let attestationHeaders = try await AppAttestationManager.shared.generateAttestationHeaders(for: challenge)
        for (key, value) in attestationHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(challenge.base64EncodedString(), forHTTPHeaderField: "X-Request-Challenge")
        
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
                
                // Initialize App Attestation in background
                if let token = self.accessToken {
                    Task {
                        await secureAPI.initializeAttestation(accessToken: token)
                    }
                }
                
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
        
        // Debug: Print response details
        DebugLogger.shared.log("🔍 Auth Response Debug:")
        if let httpResponse = response as? HTTPURLResponse {
            DebugLogger.shared.log("  Status Code: \(httpResponse.statusCode)")
            DebugLogger.shared.log("  Headers: \(httpResponse.allHeaderFields)")
        }
        DebugLogger.shared.log("  Data Length: \(data.count)")
        if let responseString = String(data: data, encoding: .utf8) {
            DebugLogger.shared.log("  Response Body: \(responseString)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("❌ Auth failed with status code: \(statusCode)")
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Backend authentication failed with status \(statusCode)"])
        }
        
        let authResponse: AuthResponse
        do {
            authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            print("❌ Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse server response: \(error.localizedDescription)"])
        }
        
        print("🔍 Parsed AuthResponse:")
        print("  Success: \(authResponse.success)")
        print("  User: \(authResponse.user?.email ?? "nil")")
        print("  Access Token: \(authResponse.accessToken != nil ? "present" : "nil")")
        print("  Error: \(authResponse.error ?? "nil")")
        
        if authResponse.success, let user = authResponse.user, let token = authResponse.accessToken {
            print("🔍 Setting authentication state...")
            await MainActor.run {
                self.currentUser = user
                self.accessToken = token
                self.isAuthenticated = true
                print("🔍 Auth state updated on main thread - isAuthenticated: \(self.isAuthenticated)")
            }
            
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
            
            // Initialize App Attestation in background
            if let token = self.accessToken {
                Task {
                    await secureAPI.initializeAttestation(accessToken: token)
                }
            }
            
            print("✅ Backend authentication successful - User: \(user.email), Auth State: \(self.isAuthenticated)")
            
            // Force UI update on next run loop to ensure all observers are notified
            DispatchQueue.main.async {
                self.objectWillChange.send()
                print("🔍 Sent objectWillChange notification")
            }
        } else {
            print("❌ Auth Response Validation Failed:")
            print("  Success: \(authResponse.success)")
            print("  User nil: \(authResponse.user == nil)")
            print("  Token nil: \(authResponse.accessToken == nil)")
            print("  Error: \(authResponse.error ?? "none")")
            
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: authResponse.error ?? "Authentication failed - invalid response format"])
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
        let keychain = KeychainManager.shared
        
        // Store user data
        if let user = currentUser, let userData = try? JSONEncoder().encode(user) {
            _ = keychain.store(userData, for: "hamrah_user")
        }
        
        // Store tokens securely
        if let token = accessToken {
            _ = keychain.store(token, for: "hamrah_access_token")
        }
        
        // Store authentication state
        _ = keychain.store(isAuthenticated, for: "hamrah_is_authenticated")
        
        // Store timestamp for token validation
        _ = keychain.store(Date().timeIntervalSince1970, for: "hamrah_auth_timestamp")
    }
    
    private func loadStoredAuth() {
        let keychain = KeychainManager.shared
        
        // First try to migrate from UserDefaults if data exists there
        migrateFromUserDefaults()
        
        // Load from secure Keychain
        isAuthenticated = keychain.retrieveBool(for: "hamrah_is_authenticated") ?? false
        accessToken = keychain.retrieveString(for: "hamrah_access_token")
        
        if let userData = keychain.retrieve(for: "hamrah_user"),
           let user = try? JSONDecoder().decode(HamrahUser.self, from: userData) {
            currentUser = user
        }
        
        // Check if token is stale (older than 24 hours)
        let authTimestamp = keychain.retrieveDouble(for: "hamrah_auth_timestamp") ?? 0
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
        let keychain = KeychainManager.shared
        
        // Clear from Keychain
        _ = keychain.clearAllHamrahData()
        
        // Also clear from UserDefaults in case of migration
        UserDefaults.standard.removeObject(forKey: "hamrah_user")
        UserDefaults.standard.removeObject(forKey: "hamrah_access_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_refresh_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_is_authenticated")
        UserDefaults.standard.removeObject(forKey: "hamrah_auth_timestamp")
        UserDefaults.standard.removeObject(forKey: "hamrah_token_expires_at")
        // Don't clear last used email for passkey auto-login
    }
    
    // MARK: - Migration from UserDefaults to Keychain
    
    private func migrateFromUserDefaults() {
        let keychain = KeychainManager.shared
        
        // Check if we've already migrated
        if keychain.retrieveBool(for: "hamrah_migration_completed") == true {
            return
        }
        
        print("🔄 Migrating auth data from UserDefaults to Keychain...")
        
        // Migrate user data
        if let userData = UserDefaults.standard.data(forKey: "hamrah_user") {
            _ = keychain.store(userData, for: "hamrah_user")
            UserDefaults.standard.removeObject(forKey: "hamrah_user")
        }
        
        // Migrate access token
        if let accessToken = UserDefaults.standard.string(forKey: "hamrah_access_token") {
            _ = keychain.store(accessToken, for: "hamrah_access_token")
            UserDefaults.standard.removeObject(forKey: "hamrah_access_token")
        }
        
        // Migrate refresh token
        if let refreshToken = UserDefaults.standard.string(forKey: "hamrah_refresh_token") {
            _ = keychain.store(refreshToken, for: "hamrah_refresh_token")
            UserDefaults.standard.removeObject(forKey: "hamrah_refresh_token")
        }
        
        // Migrate authentication state
        let wasAuthenticated = UserDefaults.standard.bool(forKey: "hamrah_is_authenticated")
        if UserDefaults.standard.object(forKey: "hamrah_is_authenticated") != nil {
            _ = keychain.store(wasAuthenticated, for: "hamrah_is_authenticated")
            UserDefaults.standard.removeObject(forKey: "hamrah_is_authenticated")
        }
        
        // Migrate timestamp
        let timestamp = UserDefaults.standard.double(forKey: "hamrah_auth_timestamp")
        if timestamp > 0 {
            _ = keychain.store(timestamp, for: "hamrah_auth_timestamp")
            UserDefaults.standard.removeObject(forKey: "hamrah_auth_timestamp")
        }
        
        // Migrate token expiry
        let expiresAt = UserDefaults.standard.double(forKey: "hamrah_token_expires_at")
        if expiresAt > 0 {
            _ = keychain.store(expiresAt, for: "hamrah_token_expires_at")
            UserDefaults.standard.removeObject(forKey: "hamrah_token_expires_at")
        }
        
        // Mark migration as completed
        _ = keychain.store(true, for: "hamrah_migration_completed")
        
        print("✅ Migration to Keychain completed successfully")
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
        print("🍎 Apple Sign-In authorization completed")
        Task {
            do {
                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                    print("🍎 Apple ID Credential received:")
                    print("  User ID: \(appleIDCredential.user)")
                    print("  Email: \(appleIDCredential.email ?? "nil")")
                    print("  Full Name: \(appleIDCredential.fullName?.description ?? "nil")")
                    
                    guard let identityToken = appleIDCredential.identityToken,
                          let tokenString = String(data: identityToken, encoding: .utf8) else {
                        throw NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No identity token"])
                    }
                    
                    print("🍎 Identity token received, length: \(tokenString.count)")
                    
                    let additionalData = [
                        "email": appleIDCredential.email ?? "",
                        "name": [appleIDCredential.fullName?.givenName, appleIDCredential.fullName?.familyName]
                            .compactMap { $0 }
                            .joined(separator: " ")
                    ]
                    
                    print("🍎 Sending authentication request to backend...")
                    try await authenticateWithBackend(provider: "apple", credential: tokenString, additionalData: additionalData)
                    print("🍎 Backend authentication completed successfully")
                } else {
                    print("❌ Apple Sign-In: Invalid credential type")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                }
                print("❌ Apple Sign-In completion error: \(error)")
            }
            await MainActor.run {
                isLoading = false
            }
            print("🍎 Apple Sign-In flow completed, isLoading set to false")
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

// MARK: - Helper Extensions for NativeAuthManager

extension NativeAuthManager {
    private func generateRequestChallenge(url: URL, method: String, body: [String: Any]?) -> Data {
        // Create a deterministic challenge based on request details
        var challengeString = "\(method):\(url.absoluteString)"
        
        if let body = body {
            // Sort keys for deterministic serialization
            let sortedKeys = body.keys.sorted()
            let bodyString = sortedKeys.map { key in
                "\(key):\(body[key] ?? "")"
            }.joined(separator: ",")
            challengeString += ":\(bodyString)"
        }
        
        challengeString += ":\(Date().timeIntervalSince1970)"
        
        return challengeString.data(using: .utf8) ?? Data()
    }
}