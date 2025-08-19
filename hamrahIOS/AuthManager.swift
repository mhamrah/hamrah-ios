//
//  AuthManager.swift
//  hamrahIOS
//
//  OAuth authentication manager using ASWebAuthenticationSession
//  Implements PKCE flow for secure authentication with hamrah.app
//

import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
@available(iOS 12.0, *)
class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var webAuthSession: ASWebAuthenticationSession?
    private let clientId = "hamrah-ios-app" // Pre-registered iOS client from migration
    private let baseURL = "https://localhost:5173" // Use local dev server with HTTPS
    private let redirectURI = "hamrah://auth/callback"
    
    // PKCE parameters
    private var codeVerifier: String?
    private var codeChallenge: String?
    
    struct UserProfile: Codable {
        let sub: String
        let name: String?
        let email: String?
        let picture: String?
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let refresh_token: String?
        let id_token: String?
        let scope: String
    }
    
    override init() {
        super.init()
        // Check for stored authentication state
        loadStoredAuth()
    }
    
    // MARK: - Public Methods
    
    func login() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("🔐 Starting OAuth login process...")
            
            // Generate PKCE parameters
            generatePKCEParameters()
            print("✅ PKCE parameters generated")
            
            // Build authorization URL
            let authURL = buildAuthorizationURL()
            print("🌐 Authorization URL: \(authURL)")
            
            // Start web authentication session
            print("🚀 Starting web authentication session...")
            let authCode = try await performWebAuthentication(authURL: authURL)
            print("✅ Received authorization code: \(authCode.prefix(10))...")
            
            // Exchange authorization code for tokens
            print("🔄 Exchanging code for tokens...")
            try await exchangeCodeForTokens(authCode: authCode)
            print("✅ Tokens received successfully")
            
            // Fetch user profile
            print("👤 Fetching user profile...")
            try await fetchUserProfile()
            print("✅ User profile fetched")
            
            isAuthenticated = true
            storeAuthState()
            print("🎉 Login completed successfully!")
            
        } catch {
            let errorMsg = "Login failed: \(error.localizedDescription)"
            errorMessage = errorMsg
            print("❌ \(errorMsg)")
            print("🔍 Full error: \(error)")
        }
        
        isLoading = false
    }
    
    func logout() {
        isAuthenticated = false
        accessToken = nil
        userProfile = nil
        clearStoredAuth()
    }
    
    func refreshTokenIfNeeded() async {
        // Implementation for token refresh would go here
        // For now, just check if we have a valid token
        guard let token = accessToken else {
            isAuthenticated = false
            return
        }
        
        // In a real implementation, you'd check token expiry and refresh if needed
        isAuthenticated = true
    }
    
    // MARK: - Private Methods
    
    private func generatePKCEParameters() {
        // Generate code verifier (random 32-byte string, base64url encoded)
        let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        codeVerifier = data.base64URLEncodedString()
        
        // Generate code challenge (SHA256 hash of verifier, base64url encoded)
        guard let verifierData = codeVerifier?.data(using: .utf8) else { return }
        let hash = SHA256.hash(data: verifierData)
        codeChallenge = Data(hash).base64URLEncodedString()
    }
    
    private func buildAuthorizationURL() -> URL {
        var components = URLComponents(string: "\(baseURL)/oidc/auth")!
        
        let state = generateRandomString(length: 32)
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        
        let finalURL = components.url!
        print("📋 Final authorization URL components:")
        print("   Base URL: \(baseURL)")
        print("   Client ID: \(clientId)")
        print("   Redirect URI: \(redirectURI)")
        print("   Code Challenge: \(codeChallenge ?? "none")")
        
        return finalURL
    }
    
    private func performWebAuthentication(authURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            webAuthSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "hamrah"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                      let authCode = codeItem.value else {
                    continuation.resume(throwing: AuthError.invalidCallback)
                    return
                }
                
                continuation.resume(returning: authCode)
            }
            
            webAuthSession?.presentationContextProvider = self
            webAuthSession?.prefersEphemeralWebBrowserSession = false
            webAuthSession?.start()
        }
    }
    
    private func exchangeCodeForTokens(authCode: String) async throws {
        guard let codeVerifier = codeVerifier else {
            throw AuthError.missingCodeVerifier
        }
        
        let tokenURL = URL(string: "\(baseURL)/oidc/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": authCode,
            "redirect_uri": redirectURI,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.access_token
    }
    
    private func fetchUserProfile() async throws {
        guard let accessToken = accessToken else {
            throw AuthError.missingAccessToken
        }
        
        let profileURL = URL(string: "\(baseURL)/oidc/userinfo")!
        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.profileFetchFailed
        }
        
        userProfile = try JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    private func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    // MARK: - Storage Methods
    
    private func storeAuthState() {
        UserDefaults.standard.set(accessToken, forKey: "hamrah_access_token")
        UserDefaults.standard.set(isAuthenticated, forKey: "hamrah_is_authenticated")
        
        if let userProfile = userProfile,
           let profileData = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(profileData, forKey: "hamrah_user_profile")
        }
    }
    
    private func loadStoredAuth() {
        accessToken = UserDefaults.standard.string(forKey: "hamrah_access_token")
        isAuthenticated = UserDefaults.standard.bool(forKey: "hamrah_is_authenticated")
        
        if let profileData = UserDefaults.standard.data(forKey: "hamrah_user_profile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            userProfile = profile
        }
    }
    
    private func clearStoredAuth() {
        UserDefaults.standard.removeObject(forKey: "hamrah_access_token")
        UserDefaults.standard.removeObject(forKey: "hamrah_is_authenticated")
        UserDefaults.standard.removeObject(forKey: "hamrah_user_profile")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCallback
    case missingCodeVerifier
    case tokenExchangeFailed
    case missingAccessToken
    case profileFetchFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidCallback:
            return "Invalid authentication callback"
        case .missingCodeVerifier:
            return "Missing PKCE code verifier"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .missingAccessToken:
            return "Missing access token"
        case .profileFetchFailed:
            return "Failed to fetch user profile"
        }
    }
}

// MARK: - Data Extensions

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}