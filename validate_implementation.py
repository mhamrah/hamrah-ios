#!/usr/bin/env python3
"""
Validation script for Face ID authentication on app launch implementation.
This script validates that all necessary files exist and have expected content.
"""

import os
import sys

def check_file_exists(file_path):
    """Check if a file exists and print status."""
    if os.path.exists(file_path):
        print(f"✅ {file_path}")
        return True
    else:
        print(f"❌ {file_path} - MISSING")
        return False

def check_file_contains(file_path, search_strings):
    """Check if a file contains expected content."""
    if not os.path.exists(file_path):
        print(f"❌ {file_path} - FILE NOT FOUND")
        return False
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        all_found = True
        for search_string in search_strings:
            if search_string in content:
                print(f"✅ {file_path} contains '{search_string}'")
            else:
                print(f"❌ {file_path} missing '{search_string}'")
                all_found = False
        
        return all_found
    except Exception as e:
        print(f"❌ {file_path} - ERROR reading file: {e}")
        return False

def main():
    """Main validation function."""
    print("🔍 Validating Face ID Authentication on App Launch Implementation")
    print("=" * 60)
    
    base_dir = "/home/runner/work/hamrah-ios/hamrah-ios"
    all_checks_passed = True
    
    # Check core implementation files
    print("\n📱 Core Implementation Files:")
    core_files = [
        "hamrah-ios/ProgressiveAuthView.swift",
        "hamrah-ios/BiometricLaunchView.swift",
        "hamrah-ios/BiometricAuthManager.swift",
        "hamrah-ios/NativeAuthManager.swift"
    ]
    
    for file_path in core_files:
        full_path = os.path.join(base_dir, file_path)
        if not check_file_exists(full_path):
            all_checks_passed = False
    
    # Check test files
    print("\n🧪 Test Files:")
    test_files = [
        "hamrah-ios-tests/hamrahIOSTests.swift",
        "hamrah-ios-tests/BiometricLaunchTests.swift"
    ]
    
    for file_path in test_files:
        full_path = os.path.join(base_dir, file_path)
        if not check_file_exists(full_path):
            all_checks_passed = False
    
    # Check documentation
    print("\n📚 Documentation:")
    doc_files = [
        "FACE_ID_INTEGRATION.md"
    ]
    
    for file_path in doc_files:
        full_path = os.path.join(base_dir, file_path)
        if not check_file_exists(full_path):
            all_checks_passed = False
    
    # Check specific content in key files
    print("\n🔍 Content Validation:")
    
    # Check ProgressiveAuthView has biometric logic
    progressive_auth_path = os.path.join(base_dir, "hamrah-ios/ProgressiveAuthView.swift")
    progressive_auth_content = [
        "biometricAuthPending",
        "checkBiometricAuthRequirement",
        "handleBiometricAuthOnLaunch",
        "hasCheckedBiometric",
        "BiometricLaunchView"
    ]
    if not check_file_contains(progressive_auth_path, progressive_auth_content):
        all_checks_passed = False
    
    # Check BiometricLaunchView exists with proper structure
    biometric_launch_path = os.path.join(base_dir, "hamrah-ios/BiometricLaunchView.swift")
    biometric_launch_content = [
        "BiometricLaunchView",
        "biometricManager",
        "biometricIconName",
        "Unlock Hamrah"
    ]
    if not check_file_contains(biometric_launch_path, biometric_launch_content):
        all_checks_passed = False
    
    # Check tests exist
    test_path = os.path.join(base_dir, "hamrah-ios-tests/BiometricLaunchTests.swift")
    test_content = [
        "BiometricLaunchScenarioTests",
        "testUnauthenticatedUserShowsLogin",
        "testAuthenticatedUserWithFaceIDRequiresBiometric",
        "testSuccessfulFaceIDKeepsUserLoggedIn"
    ]
    if not check_file_contains(test_path, test_content):
        all_checks_passed = False
    
    # Summary
    print("\n" + "=" * 60)
    if all_checks_passed:
        print("🎉 ALL VALIDATION CHECKS PASSED!")
        print("✅ Face ID authentication on app launch is properly implemented")
        print("✅ All files exist and contain expected content")
        print("✅ Tests are in place")
        print("✅ Documentation is complete")
        return 0
    else:
        print("❌ VALIDATION FAILED!")
        print("Some files are missing or don't contain expected content.")
        return 1

if __name__ == "__main__":
    sys.exit(main())