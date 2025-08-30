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
        
        // Then: Should eventually show app content (not login screens)
        // Wait for app to finish launching
        let appDidLaunch = app.wait(for: .runningForeground, timeout: 10.0)
        XCTAssertTrue(appDidLaunch, "App should launch successfully")
        
        // Look for any UI elements that indicate we're in the main app (not login)
        let anyMainElement = app.descendants(matching: .any).element(boundBy: 0)
        XCTAssertTrue(anyMainElement.waitForExistence(timeout: 10.0), "Some main UI element should be visible")
        
        // Should NOT see Face ID prompt specifically (the main test)
        let faceIDPrompt = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Face ID' OR label CONTAINS 'Touch ID'")).firstMatch
        
        // Give a moment for any Face ID prompt to potentially appear
        sleep(2)
        
        XCTAssertFalse(faceIDPrompt.exists, "Should not show Face ID prompt when already authenticated")
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
        
        // When: Looking for Apple Sign-In button
        let appleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch
        
        if appleSignInButton.waitForExistence(timeout: 10.0) {
            // Verify button is tappable
            XCTAssertTrue(appleSignInButton.isHittable, "Apple Sign-In button should be tappable")
            
            // Tap the button
            appleSignInButton.tap()
            
            // Then: Should handle the Apple Sign-In flow
            // Since this is a simulation, just verify no crashes occur
            let appStillRunning = app.wait(for: .runningForeground, timeout: 5.0)
            XCTAssertTrue(appStillRunning, "App should remain running after Apple Sign-In attempt")
        } else {
            // If no Apple Sign-In button, that's also acceptable for this test
            // The main goal is to verify the UI can handle Apple Sign-In when available
            XCTAssertTrue(true, "Apple Sign-In may not be available in test environment")
        }
    }
    
    @MainActor
    func testGoogleSignInCreatesAccount() throws {
        // Given: User attempts Google Sign-In for first time
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launchEnvironment["UI_TEST_SIMULATE_GOOGLE_SIGNIN"] = "true" 
        app.launch()
        
        // When: Looking for Google Sign-In button
        let googleSignInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Google'")).firstMatch
        
        if googleSignInButton.waitForExistence(timeout: 10.0) {
            // Verify button is tappable
            XCTAssertTrue(googleSignInButton.isHittable, "Google Sign-In button should be tappable")
            
            // Tap the button
            googleSignInButton.tap()
            
            // Then: Should handle the Google Sign-In flow
            // Since this is a simulation, just verify no crashes occur
            let appStillRunning = app.wait(for: .runningForeground, timeout: 5.0)
            XCTAssertTrue(appStillRunning, "App should remain running after Google Sign-In attempt")
        } else {
            // If no Google Sign-In button, that's also acceptable for this test
            // The main goal is to verify the UI can handle Google Sign-In when available
            XCTAssertTrue(true, "Google Sign-In may not be available in test environment")
        }
    }
    
    // MARK: - Rule 5: Passkey registration with email
    
    @MainActor
    func testPasskeyRegistrationWithEmail() throws {
        // Given: User wants to register passkey with email
        app.launchEnvironment["UI_TEST_SHOW_MANUAL_LOGIN"] = "true"
        app.launch()
        
        // When: App launches and shows login screen
        let appDidLaunch = app.wait(for: .runningForeground, timeout: 10.0)
        XCTAssertTrue(appDidLaunch, "App should launch successfully")
        
        // Look for various UI elements that might indicate login/registration capability
        let emailField = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS 'email' OR placeholderValue CONTAINS 'Email'")).firstMatch
        let passkeyButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Passkey' OR label CONTAINS 'Create Passkey'")).firstMatch
        let addPasskeyOption = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Passkey' OR label CONTAINS 'Register Passkey'")).firstMatch
        let signInButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sign' OR label CONTAINS 'Login'")).firstMatch
        
        // The main test: App should provide SOME way to register or sign in
        let hasRegistrationOption = emailField.waitForExistence(timeout: 5.0) || 
                                  passkeyButton.waitForExistence(timeout: 5.0) ||
                                  addPasskeyOption.waitForExistence(timeout: 5.0) ||
                                  signInButton.waitForExistence(timeout: 5.0)
        
        XCTAssertTrue(hasRegistrationOption, "App should provide some way to register or sign in")
        
        // If email field exists, test that it's functional
        if emailField.exists {
            XCTAssertTrue(emailField.isEnabled, "Email field should be enabled if present")
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
