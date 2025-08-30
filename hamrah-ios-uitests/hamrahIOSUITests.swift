//
//  hamrahIOSUITests.swift
//  hamrahIOSUITests
//
//  Created by Mike Hamrah on 8/10/25.
//

import XCTest

final class hamrahIOSUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - Authentication Flow UI Tests

final class AuthenticationFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Clear UserDefaults before each test to ensure clean state
        app.launchArguments.append("--reset-userdefaults")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Rule 1: Face ID enabled goes to homescreen
    
    @MainActor
    func testFaceIDEnabledGoesToHomescreen() throws {
        // Given: App is launched with Face ID enabled and valid token
        app.launchEnvironment["UI_TEST_BIOMETRIC_ENABLED"] = "true"
        app.launchEnvironment["UI_TEST_VALID_TOKEN"] = "true"
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "true"
        app.launch()
        
        // When: App launches
        
        // Then: Should show home screen (ContentView) without login screens
        // Look for elements that indicate we're on the home screen
        let homeScreenIndicator = app.navigationBars.firstMatch
        let addButton = app.buttons["Add Item"]
        let accountButton = app.buttons.matching(identifier: "person.circle").firstMatch
        
        // Should find home screen elements within reasonable time
        XCTAssertTrue(homeScreenIndicator.waitForExistence(timeout: 5.0), "Home screen navigation should be visible")
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0), "Add Item button should be visible on home screen")
        XCTAssertTrue(accountButton.waitForExistence(timeout: 5.0), "Account button should be visible on home screen")
        
        // Should NOT see login screens
        let faceIDPrompt = app.staticTexts["Use Face ID to securely access your account"]
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in with Apple'")).firstMatch
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in with Google'")).firstMatch
        
        XCTAssertFalse(faceIDPrompt.exists, "Should not show Face ID prompt when already authenticated")
        XCTAssertFalse(appleSignInButton.exists, "Should not show Apple Sign-In when authenticated")
        XCTAssertFalse(googleSignInButton.exists, "Should not show Google Sign-In when authenticated")
    }
    
    @MainActor
    func testFaceIDDisabledShowsLoginOptions() throws {
        // Given: App is launched without Face ID and no stored auth
        app.launchEnvironment["UI_TEST_BIOMETRIC_ENABLED"] = "false"
        app.launchEnvironment["UI_TEST_VALID_TOKEN"] = "false"
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "false"
        app.launch()
        
        // When: App launches
        
        // Then: Should show login options
        let loginButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign in' OR label CONTAINS 'Login'")).firstMatch
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        
        // Should find login elements within reasonable time
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10.0) || 
                     appleSignInButton.waitForExistence(timeout: 10.0) || 
                     googleSignInButton.waitForExistence(timeout: 10.0), 
                     "Should show login options when not authenticated")
    }
    
    // MARK: - Rule 2: Passkey with last email auto-login
    
    @MainActor  
    func testPasskeyWithLastEmailAutoLogin() throws {
        // Given: App has stored email but no valid token
        app.launchEnvironment["UI_TEST_BIOMETRIC_ENABLED"] = "false"
        app.launchEnvironment["UI_TEST_VALID_TOKEN"] = "false"
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "false"
        app.launchEnvironment["UI_TEST_LAST_EMAIL"] = "test@example.com"
        app.launchEnvironment["UI_TEST_HAS_PASSKEYS"] = "true"
        app.launch()
        
        // When: App launches and attempts automatic passkey login
        
        // Then: Should show passkey auto-login screen
        let passkeyPrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'passkey'")).firstMatch
        let quickSignIn = app.staticTexts["Quick Sign In"]
        let passkeyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign In with Passkey' OR label CONTAINS 'Passkey'")).firstMatch
        
        XCTAssertTrue(passkeyPrompt.waitForExistence(timeout: 10.0) || 
                     quickSignIn.waitForExistence(timeout: 10.0) ||
                     passkeyButton.waitForExistence(timeout: 10.0), 
                     "Should show passkey auto-login when email is stored and passkeys are available")
    }
    
    @MainActor
    func testNoLastEmailShowsManualLogin() throws {
        // Given: App has no stored email and no auth
        app.launchEnvironment["UI_TEST_BIOMETRIC_ENABLED"] = "false"
        app.launchEnvironment["UI_TEST_VALID_TOKEN"] = "false"
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "false"
        app.launchEnvironment["UI_TEST_LAST_EMAIL"] = ""
        app.launchEnvironment["UI_TEST_HAS_PASSKEYS"] = "false"
        app.launch()
        
        // When: App launches with no stored email
        
        // Then: Should show manual login options  
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email' OR placeholderValue CONTAINS 'Email'")).firstMatch
        
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 10.0) || 
                     googleSignInButton.waitForExistence(timeout: 10.0) || 
                     emailField.waitForExistence(timeout: 10.0), 
                     "Should show manual login options when no stored email")
    }
    
    // MARK: - Rule 3: Manual login with passkey, Apple, Google
    
    @MainActor
    func testManualLoginOptionsAvailable() throws {
        // Given: App shows manual login screen
        app.launchEnvironment["UI_TEST_BIOMETRIC_ENABLED"] = "false"
        app.launchEnvironment["UI_TEST_VALID_TOKEN"] = "false"
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "false"
        app.launch()
        
        // When: Checking available login options
        
        // Then: Should see all three login methods
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        let passkeyOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Passkey'")).firstMatch
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email'")).firstMatch
        
        // Wait for login screen to load
        let loginLoaded = appleSignInButton.waitForExistence(timeout: 10.0) || 
                         googleSignInButton.waitForExistence(timeout: 10.0) || 
                         emailField.waitForExistence(timeout: 10.0)
        
        XCTAssertTrue(loginLoaded, "Should show login screen")
        
        // Should have Apple Sign-In option
        XCTAssertTrue(appleSignInButton.exists || appleSignInButton.waitForExistence(timeout: 3.0), 
                     "Should show Apple Sign-In option")
        
        // Should have Google Sign-In option  
        XCTAssertTrue(googleSignInButton.exists || googleSignInButton.waitForExistence(timeout: 3.0), 
                     "Should show Google Sign-In option")
        
        // Should have passkey or email option for passkey registration
        XCTAssertTrue(passkeyOption.exists || emailField.exists || 
                     passkeyOption.waitForExistence(timeout: 3.0) || 
                     emailField.waitForExistence(timeout: 3.0), 
                     "Should show passkey or email option for passkey registration")
    }
    
    @MainActor
    func testAppleSignInButtonTappable() throws {
        // Given: Manual login screen is showing
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launch()
        
        // When: Tapping Apple Sign-In button
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        
        if appleSignInButton.waitForExistence(timeout: 10.0) {
            XCTAssertTrue(appleSignInButton.isEnabled, "Apple Sign-In button should be enabled")
            XCTAssertTrue(appleSignInButton.isHittable, "Apple Sign-In button should be tappable")
        }
    }
    
    @MainActor
    func testGoogleSignInButtonTappable() throws {
        // Given: Manual login screen is showing
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"  
        app.launch()
        
        // When: Checking Google Sign-In button
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        
        if googleSignInButton.waitForExistence(timeout: 10.0) {
            XCTAssertTrue(googleSignInButton.isEnabled, "Google Sign-In button should be enabled")
            XCTAssertTrue(googleSignInButton.isHittable, "Google Sign-In button should be tappable")
        }
    }
    
    // MARK: - Rule 4: Automatic account creation for Apple/Google
    
    @MainActor
    func testAppleSignInCreatesAccount() throws {
        // Given: User attempts Apple Sign-In for first time
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launchEnvironment["UI_TEST_SIMULATE_APPLE_SIGNIN"] = "true"
        app.launch()
        
        // When: Tapping Apple Sign-In (simulated)
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        
        if appleSignInButton.waitForExistence(timeout: 10.0) {
            // Simulate successful Apple Sign-In leading to account creation
            appleSignInButton.tap()
            
            // Then: Should eventually show home screen (new account created)
            let homeScreenIndicator = app.navigationBars.firstMatch
            let loadingIndicator = app.activityIndicators.firstMatch
            
            // Wait for loading to complete and home screen to appear
            if loadingIndicator.waitForExistence(timeout: 5.0) {
                // Wait for loading to finish
                XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 15.0), 
                            "Loading should complete within reasonable time")
            }
            
            // Should eventually reach home screen
            XCTAssertTrue(homeScreenIndicator.waitForExistence(timeout: 10.0), 
                         "Should show home screen after successful Apple Sign-In account creation")
        }
    }
    
    @MainActor
    func testGoogleSignInCreatesAccount() throws {
        // Given: User attempts Google Sign-In for first time
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launchEnvironment["UI_TEST_SIMULATE_GOOGLE_SIGNIN"] = "true" 
        app.launch()
        
        // When: Tapping Google Sign-In (simulated)
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        
        if googleSignInButton.waitForExistence(timeout: 10.0) {
            googleSignInButton.tap()
            
            // Then: Should eventually show home screen (new account created)
            let homeScreenIndicator = app.navigationBars.firstMatch
            let loadingIndicator = app.activityIndicators.firstMatch
            
            // Wait for loading to complete
            if loadingIndicator.waitForExistence(timeout: 5.0) {
                XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 15.0), 
                            "Loading should complete within reasonable time")
            }
            
            // Should eventually reach home screen
            XCTAssertTrue(homeScreenIndicator.waitForExistence(timeout: 10.0), 
                         "Should show home screen after successful Google Sign-In account creation")
        }
    }
    
    // MARK: - Rule 5: Passkey registration with email
    
    @MainActor
    func testPasskeyRegistrationWithEmail() throws {
        // Given: User wants to register passkey with email
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launch()
        
        // When: Looking for email input for passkey registration
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email' OR placeholderValue CONTAINS 'Email'")).firstMatch
        let passkeyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Passkey' OR label CONTAINS 'Create Passkey'")).firstMatch
        
        if emailField.waitForExistence(timeout: 10.0) {
            // Should be able to enter email
            XCTAssertTrue(emailField.isEnabled, "Email field should be enabled for passkey registration")
            
            // Enter test email
            emailField.tap()
            emailField.typeText("newuser@example.com")
            
            // Should have passkey registration option
            if passkeyButton.waitForExistence(timeout: 5.0) {
                XCTAssertTrue(passkeyButton.isEnabled, "Passkey registration button should be enabled")
                XCTAssertTrue(passkeyButton.isHittable, "Passkey registration button should be tappable")
            }
        } else {
            // Alternative: Look for "Add Passkey" or similar option
            let addPasskeyOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Passkey' OR label CONTAINS 'Register Passkey'")).firstMatch
            
            XCTAssertTrue(addPasskeyOption.waitForExistence(timeout: 5.0) || emailField.waitForExistence(timeout: 5.0), 
                         "Should provide way to register passkey with email")
        }
    }
    
    @MainActor
    func testEmailValidationForPasskey() throws {
        // Given: Email field for passkey registration is visible
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launch()
        
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email'")).firstMatch
        
        if emailField.waitForExistence(timeout: 10.0) {
            // When: Entering invalid email
            emailField.tap()
            emailField.typeText("invalid-email")
            
            // Should handle invalid email appropriately
            let registerButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Register' OR label CONTAINS 'Create' OR label CONTAINS 'Passkey'")).firstMatch
            
            if registerButton.waitForExistence(timeout: 5.0) {
                registerButton.tap()
                
                // Then: Should show error or prevent submission
                let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'email' AND label CONTAINS 'valid'")).firstMatch
                
                // Either shows error or doesn't proceed (both are acceptable)
                XCTAssertTrue(errorMessage.waitForExistence(timeout: 3.0) || 
                             !app.navigationBars.firstMatch.waitForExistence(timeout: 3.0), 
                             "Should handle invalid email appropriately")
            }
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testCompleteAuthFlowFromFreshInstall() throws {
        // Given: Fresh app install (no stored data)
        app.launchEnvironment["UI_TEST_FRESH_INSTALL"] = "true"
        app.launch()
        
        // When: App launches for first time
        
        // Then: Should show onboarding or login options
        let loginElements = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign' OR label CONTAINS 'Login' OR label CONTAINS 'Apple' OR label CONTAINS 'Google'"))
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email'")).firstMatch
        
        let hasLoginOptions = loginElements.firstMatch.waitForExistence(timeout: 10.0) || 
                             emailField.waitForExistence(timeout: 10.0)
        
        XCTAssertTrue(hasLoginOptions, "Fresh install should show login options")
    }
    
    @MainActor
    func testLogoutAndReauthentication() throws {
        // Given: User is authenticated
        app.launchEnvironment["UI_TEST_AUTHENTICATED"] = "true" 
        app.launch()
        
        // When: User logs out
        let accountButton = app.buttons.matching(identifier: "person.circle").firstMatch
        if accountButton.waitForExistence(timeout: 10.0) {
            accountButton.tap()
            
            // Look for logout option
            let logoutButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Logout' OR label CONTAINS 'Sign Out'")).firstMatch
            
            if logoutButton.waitForExistence(timeout: 5.0) {
                logoutButton.tap()
                
                // Then: Should return to login screen
                let loginOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign' OR label CONTAINS 'Apple' OR label CONTAINS 'Google'")).firstMatch
                
                XCTAssertTrue(loginOptions.waitForExistence(timeout: 10.0), 
                             "Should show login options after logout")
            }
        }
    }
}
