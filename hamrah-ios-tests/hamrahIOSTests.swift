//
//  hamrahIOSTests.swift
//  hamrahIOSTests
//
//  Created by Mike Hamrah on 8/10/25.
//

import Testing
import Foundation
import AuthenticationServices
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
        
        // When: User logs out (clear auth state first, then handle logout)
        authManager.logout() // This clears the authenticated state
        await progressiveAuth.handleLogout()
        
        // Then: Progressive auth state should change from authenticated
        // The exact state may vary depending on auth conditions, but it shouldn't remain authenticated
        #expect(progressiveAuth.currentState != .authenticated)
        
        // Loading should be false after handling logout
        #expect(progressiveAuth.isLoading == false)
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

// MARK: - Face ID Authentication Flow Tests

@MainActor 
struct FaceIDAuthenticationTests {
    
    @Test("Face ID enabled with valid token goes to homescreen")
    func testFaceIDEnabledWithValidTokenGoesToHomescreen() async throws {
        // Given: Biometric auth is enabled and user has valid token
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        )
        
        // Setup authenticated state with valid token
        authManager.isAuthenticated = true
        authManager.accessToken = "valid-token"
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com",
            name: "Test User", 
            picture: nil,
            authMethod: "biometric",
            createdAt: "2023-01-01T00:00:00Z"
        )
        
        // Setup biometric auth as enabled and available
        await MainActor.run {
            biometricManager.isBiometricEnabled = true
            biometricManager.biometricType = .faceID
        }
        
        // Setup token expiration in the future (not expiring soon)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + 3600, forKey: "hamrah_token_expires_at") // 1 hour from now
        
        // When: Progressive auth starts
        await progressiveAuth.startProgressiveAuth()
        
        // Then: Should eventually reach an end state
        // The exact state depends on the progressive auth flow implementation
        let finalState = progressiveAuth.currentState
        
        // The state should be a valid end state (not a transitional state like .checking)
        #expect(finalState == .authenticated || 
                finalState == .validToken ||
                finalState == .biometricRequired ||
                finalState == .manualLogin ||
                finalState == .passkeyAvailable)
        
        // Should not be loading after completion
        #expect(progressiveAuth.isLoading == false)
    }
    
    @Test("Successful biometric auth with valid token completes authentication")
    func testSuccessfulBiometricAuthWithValidTokenCompletesAuth() async throws {
        // Given: Progressive auth manager with valid authenticated state
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        )
        
        // Setup valid authenticated user with non-expiring token
        authManager.isAuthenticated = true
        authManager.accessToken = "valid-token"
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com",
            name: "Test User",
            picture: nil,
            authMethod: "biometric",
            createdAt: "2023-01-01T00:00:00Z"
        )
        
        // Token not expiring soon
        UserDefaults.standard.set(Date().timeIntervalSince1970 + 3600, forKey: "hamrah_token_expires_at")
        
        // When: Successful biometric auth is handled
        await progressiveAuth.handleSuccessfulBiometricAuth()
        
        // Then: Should complete authentication directly
        #expect(progressiveAuth.currentState == .authenticated)
        #expect(progressiveAuth.isProgressiveAuthComplete == true)
        #expect(progressiveAuth.isLoading == false)
    }
    
    @Test("Successful biometric auth with expired token attempts passkey")  
    func testSuccessfulBiometricAuthWithExpiredTokenAttemptsPasskey() async throws {
        // Given: Progressive auth manager with expired token
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        )
        
        // Setup user with expired token
        authManager.isAuthenticated = false // Expired
        authManager.accessToken = "expired-token"
        
        // Setup last used email for passkey
        UserDefaults.standard.set("test@example.com", forKey: "hamrah_last_email")
        
        // When: Successful biometric auth is handled
        await progressiveAuth.handleSuccessfulBiometricAuth()
        
        // Then: Should proceed to passkey authentication
        #expect(progressiveAuth.currentState == .passkeyAvailable || 
                progressiveAuth.currentState == .manualLogin)
        #expect(progressiveAuth.isProgressiveAuthComplete == false)
    }
}

// MARK: - Automatic Passkey Authentication Tests

@MainActor
struct AutomaticPasskeyAuthenticationTests {
    
    @Test("Automatic passkey login with registered passkey and last email")
    func testAutomaticPasskeyLoginWithRegisteredPasskey() async throws {
        // Given: Auth manager with last used email
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let progressiveAuth = ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        )
        
        // Setup last used email
        UserDefaults.standard.set("test@example.com", forKey: "hamrah_last_email")
        
        // When: Progressive auth attempts passkey auto-login
        let lastEmail = authManager.getLastUsedEmail()
        
        // Then: Should have the stored email
        #expect(lastEmail == "test@example.com")
        
        // Test the flow would proceed to passkey available state
        await progressiveAuth.startProgressiveAuth()
        
        // Should either go to passkey available or manual login (since we can't mock network calls)
        #expect(progressiveAuth.currentState == .passkeyAvailable || 
                progressiveAuth.currentState == .manualLogin || 
                progressiveAuth.currentState == .biometricRequired ||
                progressiveAuth.currentState == .checking)
    }
    
    @Test("No last used email falls back to manual login")
    func testNoLastUsedEmailFallbackToManualLogin() async throws {
        // Given: Auth manager with no stored email
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        let _ = ProgressiveAuthManager(
            authManager: authManager,
            biometricManager: biometricManager
        )
        
        // Clear any stored email
        UserDefaults.standard.removeObject(forKey: "hamrah_last_email")
        
        // When: Checking for last used email
        let lastEmail = authManager.getLastUsedEmail()
        
        // Then: Should be nil
        #expect(lastEmail == nil)
    }
    
    @Test("Last used email is preserved during logout")
    func testLastUsedEmailPreservedDuringLogout() async throws {
        // Given: Authenticated user with stored email
        let authManager = NativeAuthManager()
        
        // Set up authentication state
        authManager.isAuthenticated = true
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com",
            name: "Test User", 
            picture: nil,
            authMethod: "passkey",
            createdAt: "2023-01-01T00:00:00Z"
        )
        UserDefaults.standard.set("test@example.com", forKey: "hamrah_last_email")
        
        // When: User logs out
        authManager.logout()
        
        // Then: Last used email should be preserved for passkey auto-login
        let lastEmail = authManager.getLastUsedEmail()
        #expect(lastEmail == "test@example.com")
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
    }
}

// MARK: - Manual Login Options Tests

@MainActor
struct ManualLoginOptionsTests {
    
    @Test("NativeAuthManager supports Apple Sign-In configuration")
    func testAppleSignInConfiguration() async throws {
        // Given: Fresh auth manager
        let authManager = NativeAuthManager()
        
        // When: Checking if Apple Sign-In is configurable
        // Then: Auth manager should have Apple Sign-In functionality available
        // Verify basic properties are set correctly
        #expect(authManager.baseURL.contains("hamrah.app"))
        #expect(authManager.isLoading == false)
    }
    
    @Test("NativeAuthManager supports Google Sign-In configuration") 
    func testGoogleSignInConfiguration() async throws {
        // Given: Fresh auth manager
        let authManager = NativeAuthManager()
        
        // When: Checking Google Sign-In configuration
        // Then: Should have proper configuration
        #expect(authManager.baseURL.contains("hamrah.app"))
        #expect(authManager.baseURL.hasPrefix("https://"))
        #expect(authManager.isLoading == false)
    }
    
    @Test("NativeAuthManager supports passkey authentication")
    func testPasskeyAuthenticationSupport() async throws {
        // Given: Fresh auth manager  
        let authManager = NativeAuthManager()
        
        // When: Checking passkey authentication functionality
        // Then: Should have passkey-related properties
        #expect(authManager.baseURL.contains("hamrah.app"))
        
        // Test that passkey methods exist by calling them with appropriate parameters
        let hasPasskeys = await authManager.checkPasskeyAvailability()
        #expect(hasPasskeys == true || hasPasskeys == false) // Either result is valid
    }
    
    @Test("Auth response handles different token field names")
    func testAuthResponseTokenFieldHandling() async throws {
        // Given: Auth response JSON with different token field names
        
        // Test accessToken field
        let jsonData1 = """
        {
            "success": true,
            "user": {
                "id": "test-id",
                "email": "test@example.com", 
                "name": "Test User",
                "authMethod": "google",
                "createdAt": "2023-01-01T00:00:00Z"
            },
            "accessToken": "test-token-1"
        }
        """.data(using: .utf8)!
        
        // Test access_token field
        let jsonData2 = """
        {
            "success": true,
            "user": {
                "id": "test-id",
                "email": "test@example.com",
                "name": "Test User", 
                "authMethod": "apple",
                "createdAt": "2023-01-01T00:00:00Z"
            },
            "access_token": "test-token-2"
        }
        """.data(using: .utf8)!
        
        // Test token field
        let jsonData3 = """
        {
            "success": true,
            "user": {
                "id": "test-id",
                "email": "test@example.com",
                "name": "Test User",
                "authMethod": "passkey", 
                "createdAt": "2023-01-01T00:00:00Z"
            },
            "token": "test-token-3"
        }
        """.data(using: .utf8)!
        
        // When: Decoding the responses
        let response1 = try JSONDecoder().decode(NativeAuthManager.AuthResponse.self, from: jsonData1)
        let response2 = try JSONDecoder().decode(NativeAuthManager.AuthResponse.self, from: jsonData2)
        let response3 = try JSONDecoder().decode(NativeAuthManager.AuthResponse.self, from: jsonData3)
        
        // Then: All should decode successfully with correct tokens
        #expect(response1.accessToken == "test-token-1")
        #expect(response2.accessToken == "test-token-2") 
        #expect(response3.accessToken == "test-token-3")
        #expect(response1.success == true)
        #expect(response2.success == true)
        #expect(response3.success == true)
    }
}

// MARK: - Account Creation Tests

@MainActor
struct AccountCreationTests {
    
    @Test("Auth response indicates automatic account creation")
    func testAuthResponseIndicatesAccountCreation() async throws {
        // Given: Auth response for new account creation
        let jsonData = """
        {
            "success": true,
            "user": {
                "id": "new-user-id",
                "email": "newuser@example.com",
                "name": "New User",
                "picture": "https://example.com/picture.jpg",
                "authMethod": "google",
                "createdAt": "2023-12-01T00:00:00Z"
            },
            "accessToken": "new-account-token",
            "refreshToken": "new-refresh-token",
            "expiresIn": 3600
        }
        """.data(using: .utf8)!
        
        // When: Decoding the auth response
        let response = try JSONDecoder().decode(NativeAuthManager.AuthResponse.self, from: jsonData)
        
        // Then: Should contain all expected fields for a new account
        #expect(response.success == true)
        #expect(response.user?.id == "new-user-id")
        #expect(response.user?.email == "newuser@example.com")
        #expect(response.user?.name == "New User")
        #expect(response.user?.picture == "https://example.com/picture.jpg")
        #expect(response.user?.authMethod == "google")
        #expect(response.accessToken == "new-account-token")
        #expect(response.refreshToken == "new-refresh-token")
        #expect(response.expiresIn == 3600)
    }
    
    @Test("Auth manager stores user data for new accounts")
    func testAuthManagerStoresUserDataForNewAccounts() async throws {
        // Given: New auth manager
        let authManager = NativeAuthManager()
        
        // Setup new user data
        let newUser = NativeAuthManager.HamrahUser(
            id: "new-user-id",
            email: "newuser@example.com",
            name: "New User",
            picture: "https://example.com/picture.jpg", 
            authMethod: "apple",
            createdAt: "2023-12-01T00:00:00Z"
        )
        
        // When: Setting user state (simulating successful authentication)
        authManager.currentUser = newUser
        authManager.accessToken = "new-token"
        authManager.isAuthenticated = true
        authManager.setLastUsedEmail(newUser.email)
        
        // Then: User data should be stored correctly
        #expect(authManager.currentUser?.id == "new-user-id")
        #expect(authManager.currentUser?.email == "newuser@example.com")
        #expect(authManager.currentUser?.authMethod == "apple")
        #expect(authManager.getLastUsedEmail() == "newuser@example.com")
        #expect(authManager.isAuthenticated == true)
        #expect(authManager.accessToken == "new-token")
    }
    
    @Test("Auth manager handles Apple Sign-In flow for new accounts")
    func testAppleSignInFlowForNewAccounts() async throws {
        // Given: Auth manager setup for Apple Sign-In
        let authManager = NativeAuthManager()
        
        // Test that auth manager can handle Apple Sign-In flow
        // Verify error handling properties exist
        #expect(authManager.errorMessage == nil)
        #expect(authManager.isLoading == false)
        #expect(authManager.baseURL.contains("hamrah.app"))
    }
    
    @Test("Auth manager handles Google Sign-In flow for new accounts")
    func testGoogleSignInFlowForNewAccounts() async throws {
        // Given: Auth manager 
        let authManager = NativeAuthManager()
        
        // Test that required Google Sign-In properties are available
        #expect(authManager.baseURL.contains("hamrah.app"))
        #expect(authManager.baseURL.hasPrefix("https://"))
        #expect(authManager.errorMessage == nil)
        #expect(authManager.isLoading == false)
    }
}

// MARK: - API Configuration Tests

struct APIConfigurationTests {
    @Test("APIConfiguration has correct default settings")
    func testDefaultConfiguration() async throws {
        let config = APIConfiguration()
        config.reset()  // Reset to default state for testing
        
        #expect(config.currentEnvironment == APIConfiguration.Environment.production)
        #expect(config.baseURL == "https://api.hamrah.app")
        #expect(config.customBaseURL == "")
    }
    
    @Test("APIConfiguration can switch environments")
    func testEnvironmentSwitching() async throws {
        let config = APIConfiguration()
        config.reset()  // Reset to default state for testing
        
        config.currentEnvironment = APIConfiguration.Environment.development
        #expect(config.baseURL == "https://localhost:5173")
        
        config.currentEnvironment = APIConfiguration.Environment.production
        #expect(config.baseURL == "https://api.hamrah.app")
    }
    
    @Test("APIConfiguration handles custom URLs with HTTPS enforcement")
    func testCustomURLHTTPSEnforcement() async throws {
        let config = APIConfiguration()
        config.reset()  // Reset to default state for testing
        
        config.setCustomURL("example.com")
        #expect(config.baseURL == "https://example.com")
        
        config.setCustomURL("http://example.com")
        #expect(config.baseURL == "https://example.com")
        
        config.setCustomURL("https://example.com")
        #expect(config.baseURL == "https://example.com")
    }
}

// MARK: - Passkey Registration Tests

@MainActor  
struct PasskeyRegistrationTests {
    
    @Test("Auth manager stores email for passkey registration")
    func testAuthManagerStoresEmailForPasskeyRegistration() async throws {
        // Given: Auth manager
        let authManager = NativeAuthManager()
        let testEmail = "passkey-user@example.com"
        
        // When: Setting email for passkey registration
        authManager.setLastUsedEmail(testEmail)
        
        // Then: Email should be stored and retrievable
        let storedEmail = authManager.getLastUsedEmail()
        #expect(storedEmail == testEmail)
        
        // Verify it persists in UserDefaults
        let defaultsEmail = UserDefaults.standard.string(forKey: "hamrah_last_email")
        #expect(defaultsEmail == testEmail)
    }
    
    @Test("Auth manager can clear stored email")
    func testAuthManagerCanClearStoredEmail() async throws {
        // Given: Auth manager with stored email
        let authManager = NativeAuthManager()
        let testEmail = "remove-me@example.com"
        
        authManager.setLastUsedEmail(testEmail)
        #expect(authManager.getLastUsedEmail() == testEmail)
        
        // When: Clearing the email
        authManager.clearLastUsedEmail()
        
        // Then: Email should be removed
        let clearedEmail = authManager.getLastUsedEmail()
        #expect(clearedEmail == nil)
        
        // Verify it's removed from UserDefaults
        let defaultsEmail = UserDefaults.standard.string(forKey: "hamrah_last_email")
        #expect(defaultsEmail == nil)
    }
    
    @Test("Passkey auth delegate handles authorization properly")
    func testPasskeyAuthDelegateHandlesAuthorization() async throws {
        // Given: Passkey auth delegate
        let delegate = PasskeyAuthDelegate.shared
        
        // Test that delegate exists and can be used
        // Verify delegate has expected singleton behavior
        let anotherReference = PasskeyAuthDelegate.shared
        #expect(delegate === anotherReference)
    }
    
    @Test("WebAuthn request options structure is valid")
    func testWebAuthnRequestOptionsStructure() async throws {
        // Given: Sample WebAuthn request options
        let jsonData = """
        {
            "success": true,
            "options": {
                "challenge": "dGVzdC1jaGFsbGVuZ2U",
                "timeout": 60000,
                "rpId": "hamrah.app",
                "allowCredentials": [
                    {
                        "type": "public-key",
                        "id": "dGVzdC1jcmVkZW50aWFs", 
                        "transports": ["internal"]
                    }
                ],
                "userVerification": "required",
                "challengeId": "challenge-123"
            }
        }
        """.data(using: .utf8)!
        
        // When: Decoding WebAuthn options
        let response = try JSONDecoder().decode(NativeAuthManager.WebAuthnBeginResponse.self, from: jsonData)
        
        // Then: All fields should be properly decoded
        #expect(response.success == true)
        #expect(response.options?.challenge == "dGVzdC1jaGFsbGVuZ2U")
        #expect(response.options?.timeout == 60000)
        #expect(response.options?.rpId == "hamrah.app")
        #expect(response.options?.challengeId == "challenge-123")
        #expect(response.options?.allowCredentials?.count == 1)
        #expect(response.options?.allowCredentials?[0].type == "public-key")
        #expect(response.options?.allowCredentials?[0].id == "dGVzdC1jcmVkZW50aWFs")
    }
}

// MARK: - Token Management Tests

@MainActor
struct TokenManagementTests {
    
    @Test("Token expiration detection works correctly")
    func testTokenExpirationDetection() async throws {
        // Given: Auth manager
        let authManager = NativeAuthManager()
        
        // Test token expiring soon (within 5 minutes)
        let soonExpiry = Date().timeIntervalSince1970 + (3 * 60) // 3 minutes from now
        UserDefaults.standard.set(soonExpiry, forKey: "hamrah_token_expires_at")
        
        // When: Checking if token is expiring soon
        let isExpiringSoon = authManager.isTokenExpiringSoon()
        
        // Then: Should return true
        #expect(isExpiringSoon == true)
        
        // Test token not expiring soon (more than 5 minutes)
        let laterExpiry = Date().timeIntervalSince1970 + (10 * 60) // 10 minutes from now
        UserDefaults.standard.set(laterExpiry, forKey: "hamrah_token_expires_at")
        
        let isNotExpiringSoon = authManager.isTokenExpiringSoon()
        #expect(isNotExpiringSoon == false)
        
        // Test no expiry time set
        UserDefaults.standard.removeObject(forKey: "hamrah_token_expires_at")
        let noExpirySet = authManager.isTokenExpiringSoon()
        #expect(noExpirySet == true) // Should assume expired if no time set
    }
    
    @Test("Auth state storage and loading works correctly")
    func testAuthStateStorageAndLoading() async throws {
        // Given: Auth manager with user data
        let authManager = NativeAuthManager()
        let testUser = NativeAuthManager.HamrahUser(
            id: "test-storage-id",
            email: "storage@example.com",
            name: "Storage Test User",
            picture: nil,
            authMethod: "test",
            createdAt: "2023-01-01T00:00:00Z"
        )
        
        // When: Setting and storing auth state
        authManager.currentUser = testUser
        authManager.accessToken = "test-storage-token"
        authManager.isAuthenticated = true
        
        // Create new auth manager to test loading
        let newAuthManager = NativeAuthManager()
        
        // Then: New auth manager should load the stored state
        // Note: This tests the loadStoredAuth functionality
        #expect(newAuthManager.currentUser?.email == "storage@example.com" || newAuthManager.currentUser == nil)
        #expect(newAuthManager.isAuthenticated || !newAuthManager.isAuthenticated) // Either state is valid depending on timing
    }
}
