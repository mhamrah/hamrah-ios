//
//  hamrahIOSTests.swift
//  hamrahIOSTests
//
//  Created by Mike Hamrah on 8/10/25.
//

import Testing
import Foundation
@testable import hamrah_ios

struct hamrahIOSTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

@MainActor
struct AuthManagerLogoutTests {
    
    @Test("Auth manager clears state on logout")
    func testAuthManagerLogoutClearsState() async throws {
        // Given: An authenticated auth manager
        let authManager = NativeAuthManager()
        authManager.isAuthenticated = true
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com", 
            name: "Test User",
            picture: nil,
            authMethod: "email",
            createdAt: "2023-01-01T00:00:00Z"
        )
        authManager.accessToken = "test-token"
        
        // When: Logout is called
        authManager.logout()
        
        // Then: Auth state is cleared
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.accessToken == nil)
    }
}

@MainActor
struct ProgressiveAuthLogoutTests {
    
    @Test("Progressive auth handles logout correctly")
    func testProgressiveAuthHandlesLogout() async throws {
        // Given: An authenticated progressive auth manager
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager, 
            biometricManager: biometricManager
        )
        
        // Set initial authenticated state
        authManager.isAuthenticated = true
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com", 
            name: "Test User",
            picture: nil,
            authMethod: "email",
            createdAt: "2023-01-01T00:00:00Z"
        )
        authManager.accessToken = "test-token"
        progressiveAuth.currentState = .authenticated
        
        // When: Logout is handled
        await progressiveAuth.handleLogout()
        
        // Then: Progressive auth state is reset appropriately
        #expect(progressiveAuth.currentState != .authenticated)
        #expect(progressiveAuth.currentState == .checking || 
                progressiveAuth.currentState == .manualLogin ||
                progressiveAuth.currentState == .biometricRequired ||
                progressiveAuth.currentState == .passkeyAvailable)
        #expect(progressiveAuth.isLoading == false)
        #expect(progressiveAuth.errorMessage == nil)
    }
    
    @Test("Progressive auth shows login screen after logout")
    func testProgressiveAuthShowsLoginScreenAfterLogout() async throws {
        // Given: An authenticated progressive auth manager
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager, 
            biometricManager: biometricManager
        )
        
        // Set initial authenticated state
        authManager.isAuthenticated = true
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com", 
            name: "Test User",
            picture: nil,
            authMethod: "email",
            createdAt: "2023-01-01T00:00:00Z"
        )
        authManager.accessToken = "test-token"
        progressiveAuth.currentState = .authenticated
        
        // When: User logs out (simulate auth manager logout)
        authManager.logout()
        await progressiveAuth.handleLogout()
        
        // Then: Progressive auth should show appropriate login state
        #expect(progressiveAuth.currentState != .authenticated)
        #expect(progressiveAuth.shouldShowManualLogin || 
                progressiveAuth.shouldShowBiometricPrompt || 
                progressiveAuth.shouldShowPasskeyPrompt ||
                progressiveAuth.currentState == .checking)
        #expect(progressiveAuth.isProgressiveAuthComplete == false)
    }
    
    @Test("Auth manager logout clears UserDefaults")
    func testLogoutClearsUserDefaults() async throws {
        // Given: An auth manager with stored data
        let authManager = NativeAuthManager()
        
        // Set up stored data
        UserDefaults.standard.set("test-token", forKey: "hamrah_access_token")
        UserDefaults.standard.set("refresh-token", forKey: "hamrah_refresh_token")
        UserDefaults.standard.set(true, forKey: "hamrah_is_authenticated")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "hamrah_auth_timestamp")
        
        authManager.isAuthenticated = true
        authManager.accessToken = "test-token"
        
        // When: Logout is called
        authManager.logout()
        
        // Then: UserDefaults are cleared
        #expect(UserDefaults.standard.string(forKey: "hamrah_access_token") == nil)
        #expect(UserDefaults.standard.string(forKey: "hamrah_refresh_token") == nil)
        #expect(UserDefaults.standard.bool(forKey: "hamrah_is_authenticated") == false)
        #expect(UserDefaults.standard.double(forKey: "hamrah_auth_timestamp") == 0)
        
        // Note: Last used email should NOT be cleared for passkey auto-login
        UserDefaults.standard.set("test@example.com", forKey: "hamrah_last_email")
        authManager.logout()
        #expect(UserDefaults.standard.string(forKey: "hamrah_last_email") == "test@example.com")
    }
}
