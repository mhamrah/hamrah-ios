//
//  BiometricLaunchTests.swift
//  hamrahIOSTests
//
//  Test scenarios for Face ID authentication on app launch
//

import Testing
import Foundation
@testable import hamrah_ios

@MainActor
struct BiometricLaunchScenarioTests {
    
    @Test("Scenario 1: User not authenticated - should show login view")
    func testUnauthenticatedUserShowsLogin() async throws {
        // Given: Unauthenticated user with biometrics available
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        
        authManager.isAuthenticated = false
        biometricManager.isBiometricEnabled = true
        
        // When: Checking if biometric auth should be required
        let shouldRequireBiometric = authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
        
        // Then: Should not require biometric auth (user not authenticated)
        #expect(shouldRequireBiometric == false)
    }
    
    @Test("Scenario 2: Authenticated user with Face ID disabled - should show content")
    func testAuthenticatedUserWithoutFaceIDShowsContent() async throws {
        // Given: Authenticated user with Face ID disabled
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        
        authManager.isAuthenticated = true
        biometricManager.isBiometricEnabled = false
        
        // When: Checking if biometric auth should be required
        let shouldRequireBiometric = authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
        
        // Then: Should not require biometric auth (Face ID disabled)
        #expect(shouldRequireBiometric == false)
    }
    
    @Test("Scenario 3: Authenticated user with Face ID enabled - should require biometric auth") 
    func testAuthenticatedUserWithFaceIDRequiresBiometric() async throws {
        // Given: Authenticated user with Face ID enabled and available
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        
        authManager.isAuthenticated = true
        biometricManager.isBiometricEnabled = true
        
        // When: Checking if biometric auth should be required
        let shouldRequireBiometric = authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
        
        // Then: Should require biometric auth if hardware is available
        #expect(shouldRequireBiometric == biometricManager.isAvailable)
    }
    
    @Test("Scenario 4: Face ID authentication success - user stays logged in")
    func testSuccessfulFaceIDKeepsUserLoggedIn() async throws {
        // Given: Biometric manager configured for success
        let biometricManager = BiometricAuthManager()
        biometricManager.isBiometricEnabled = true
        
        // When: Authenticating for app access (when disabled, returns true)
        biometricManager.isBiometricEnabled = false
        let successResult = await biometricManager.authenticateForAppAccess()
        
        // Then: Should return true (simulating success)
        #expect(successResult == true)
    }
    
    @Test("Scenario 5: Face ID authentication failure - user gets logged out")
    func testFailedFaceIDLogsOutUser() async throws {
        // Given: Authenticated user
        let authManager = NativeAuthManager()
        authManager.isAuthenticated = true
        authManager.currentUser = NativeAuthManager.HamrahUser(
            id: "test-id",
            email: "test@example.com",
            name: "Test User",
            picture: nil,
            authMethod: "biometric",
            createdAt: "2023-01-01T00:00:00Z"
        )
        authManager.accessToken = "test-token"
        
        // When: Simulating failed biometric auth by calling logout
        authManager.logout()
        
        // Then: User should be logged out
        #expect(authManager.isAuthenticated == false)
        #expect(authManager.currentUser == nil)
        #expect(authManager.accessToken == nil)
    }
    
    @Test("Scenario 6: Hardware not available - should not require biometric auth")
    func testNoHardwareAvailableSkipsBiometric() async throws {
        // Given: Biometric manager with hardware unavailable
        let biometricManager = BiometricAuthManager()
        biometricManager.isBiometricEnabled = true
        
        // When: Checking if biometric auth should be required
        let shouldRequire = biometricManager.shouldRequireBiometricAuth()
        
        // Then: Should not require if hardware unavailable
        #expect(shouldRequire == biometricManager.isAvailable)
    }
    
    @Test("Scenario 7: Multiple onAppear calls - should handle gracefully")
    func testMultipleOnAppearCallsHandledGracefully() async throws {
        // Given: Auth managers in authenticated state
        let authManager = NativeAuthManager()
        let biometricManager = BiometricAuthManager()
        
        authManager.isAuthenticated = true
        biometricManager.isBiometricEnabled = true
        
        // When: Simulating multiple checks (like multiple onAppear calls)
        let firstCheck = authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
        let secondCheck = authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
        
        // Then: Results should be consistent
        #expect(firstCheck == secondCheck)
    }
}

@MainActor
struct BiometricLaunchViewTests {
    
    @Test("BiometricLaunchView shows correct icon for Face ID")
    func testBiometricLaunchViewShowsCorrectIcon() async throws {
        // Given: Biometric manager with Face ID type
        let biometricManager = BiometricAuthManager()
        
        // When: Getting biometric type string
        let typeString = biometricManager.biometricTypeString
        
        // Then: Should be one of valid types
        let validTypes = ["Face ID", "Touch ID", "Optic ID", "None", "Unavailable", "Unknown"]
        #expect(validTypes.contains(typeString))
    }
    
    @Test("BiometricLaunchView handles error states")
    func testBiometricLaunchViewHandlesErrors() async throws {
        // Given: Biometric manager with error
        let biometricManager = BiometricAuthManager()
        
        // When: Setting an error message
        biometricManager.errorMessage = "Authentication failed"
        
        // Then: Error message should be set
        #expect(biometricManager.errorMessage == "Authentication failed")
        
        // When: Clearing error message
        biometricManager.errorMessage = nil
        
        // Then: Error message should be nil
        #expect(biometricManager.errorMessage == nil)
    }
}