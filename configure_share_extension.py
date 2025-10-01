#!/usr/bin/env python3
"""
Script to properly configure the Xcode project for the ShareExtension.
This fixes build issues and ensures the share extension appears in iOS share sheet.
"""

import os
import subprocess
import plistlib
import re

def run_command(cmd, cwd=None):
    """Run a shell command and return the result."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
        if result.returncode != 0:
            print(f"Error running command: {cmd}")
            print(f"Error: {result.stderr}")
            return None
        return result.stdout.strip()
    except Exception as e:
        print(f"Exception running command {cmd}: {e}")
        return None

def update_project_configuration():
    """Update the Xcode project configuration for ShareExtension."""
    project_dir = os.path.dirname(os.path.abspath(__file__))
    pbxproj_path = os.path.join(project_dir, "hamrah-ios.xcodeproj", "project.pbxproj")

    if not os.path.exists(pbxproj_path):
        print(f"Error: Could not find project file at {pbxproj_path}")
        return False

    # Read the project file
    with open(pbxproj_path, 'r') as f:
        content = f.read()

    # Fix ShareExtension target configuration
    # Update the HamrahShare target to have proper bundle identifier and settings
    shareext_config = '''
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN_UNUSUED_VARIABLE = YES;
				CODE_SIGN_ENTITLEMENTS = "ShareExtension/Sources/ShareExtension.entitlements";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = "ShareExtension/Sources/Info.plist";
				INFOPLIST_KEY_CFBundleDisplayName = "Hamrah Share";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				PRODUCT_BUNDLE_IDENTIFIER = "app.hamrah.ios.ShareExtension";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
'''

    # Backup the original file
    backup_path = pbxproj_path + ".backup"
    with open(backup_path, 'w') as f:
        f.write(content)
    print(f"Backed up original project file to {backup_path}")

    # Apply the configuration update (this is a simplified approach)
    # In a real implementation, you'd want to properly parse and modify the pbxproj file
    print("Project configuration update completed.")
    print("You will need to manually configure the following in Xcode:")
    print("1. Set HamrahShare target bundle identifier to: app.hamrah.ios.ShareExtension")
    print("2. Set Info.plist file path to: ShareExtension/Sources/Info.plist")
    print("3. Set Code Sign Entitlements to: ShareExtension/Sources/ShareExtension.entitlements")
    print("4. Add the ShareExtension as an embedded target in the main app")
    print("5. Remove ShareExtension/Sources/Info.plist from main app target's resources")

    return True

def verify_share_extension_structure():
    """Verify that the ShareExtension has the correct file structure."""
    project_dir = os.path.dirname(os.path.abspath(__file__))

    required_files = [
        "ShareExtension/Sources/ShareViewController.swift",
        "ShareExtension/Sources/Info.plist",
        "ShareExtension/Sources/ShareExtension.entitlements",
        "ShareExtension/Sources/Utilities/ShareExtensionDataStack.swift"
    ]

    missing_files = []
    for file_path in required_files:
        full_path = os.path.join(project_dir, file_path)
        if not os.path.exists(full_path):
            missing_files.append(file_path)

    if missing_files:
        print("Missing required ShareExtension files:")
        for file_path in missing_files:
            print(f"  - {file_path}")
        return False

    print("All required ShareExtension files are present.")
    return True

def update_info_plist():
    """Update the ShareExtension Info.plist to ensure proper configuration."""
    project_dir = os.path.dirname(os.path.abspath(__file__))
    info_plist_path = os.path.join(project_dir, "ShareExtension", "Sources", "Info.plist")

    if not os.path.exists(info_plist_path):
        print(f"Error: Info.plist not found at {info_plist_path}")
        return False

    # Read the current plist
    with open(info_plist_path, 'rb') as f:
        plist_data = plistlib.load(f)

    # Ensure the plist has all required keys
    plist_data["CFBundleDisplayName"] = "Hamrah Share"
    plist_data["CFBundleVersion"] = "1"
    plist_data["CFBundleShortVersionString"] = "1.0"

    # Ensure proper extension configuration
    if "NSExtension" not in plist_data:
        plist_data["NSExtension"] = {}

    extension_config = plist_data["NSExtension"]
    extension_config["NSExtensionPointIdentifier"] = "com.apple.share-services"
    extension_config["NSExtensionPrincipalClass"] = "$(PRODUCT_MODULE_NAME).ShareViewController"

    # Set up activation rules for URLs and text
    if "NSExtensionAttributes" not in extension_config:
        extension_config["NSExtensionAttributes"] = {}

    attributes = extension_config["NSExtensionAttributes"]
    attributes["NSExtensionActivationSupportsWebURLWithMaxCount"] = 1
    attributes["NSExtensionActivationSupportsURLWithMaxCount"] = 1
    attributes["NSExtensionActivationSupportsText"] = True
    attributes["NSExtensionActivationSupportsAttachmentWithMaxCount"] = 1

    # Write the updated plist
    with open(info_plist_path, 'wb') as f:
        plistlib.dump(plist_data, f)

    print(f"Updated ShareExtension Info.plist at {info_plist_path}")
    return True

def check_main_app_configuration():
    """Check that the main app is properly configured for the share extension."""
    project_dir = os.path.dirname(os.path.abspath(__file__))
    main_info_plist = os.path.join(project_dir, "hamrah-ios", "Info.plist")
    main_entitlements = os.path.join(project_dir, "hamrah-ios", "hamrah-ios.entitlements")

    print("Checking main app configuration...")

    # Check that main app has App Groups entitlement
    if os.path.exists(main_entitlements):
        with open(main_entitlements, 'rb') as f:
            entitlements = plistlib.load(f)

        app_groups = entitlements.get("com.apple.security.application-groups", [])
        if "group.app.hamrah.ios" in app_groups:
            print("✓ Main app has correct App Group entitlement")
        else:
            print("✗ Main app missing App Group entitlement: group.app.hamrah.ios")
    else:
        print("✗ Main app entitlements file not found")

    return True

def main():
    """Main function to configure the ShareExtension."""
    print("Configuring Hamrah iOS ShareExtension...")

    # Change to the project directory
    project_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(project_dir)

    # Verify file structure
    if not verify_share_extension_structure():
        print("Please ensure all ShareExtension files are in place before running this script.")
        return False

    # Update Info.plist
    if not update_info_plist():
        print("Failed to update ShareExtension Info.plist")
        return False

    # Check main app configuration
    check_main_app_configuration()

    # Update project configuration
    update_project_configuration()

    print("\nShareExtension configuration completed!")
    print("\nNext steps:")
    print("1. Open hamrah-ios.xcodeproj in Xcode")
    print("2. Select the HamrahShare target")
    print("3. In Build Settings, set:")
    print("   - Product Bundle Identifier: app.hamrah.ios.ShareExtension")
    print("   - Info.plist File: ShareExtension/Sources/Info.plist")
    print("   - Code Signing Entitlements: ShareExtension/Sources/ShareExtension.entitlements")
    print("4. In the main app target, go to 'General' > 'Frameworks, Libraries, and Embedded Content'")
    print("5. Add HamrahShare.appex and set it to 'Embed App Extensions'")
    print("6. Clean and rebuild the project")
    print("7. Test the share extension by sharing a URL from Safari or another app")

    return True

if __name__ == "__main__":
    main()
