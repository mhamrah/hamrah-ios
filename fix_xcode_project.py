#!/usr/bin/env python3
"""
Script to fix the Xcode project configuration for the ShareExtension.
This resolves build conflicts and ensures proper share extension functionality.
"""

import os
import re
import shutil
import subprocess
import uuid


def backup_project():
    """Create a backup of the project file."""
    project_path = "hamrah-ios.xcodeproj/project.pbxproj"
    backup_path = project_path + ".backup"
    shutil.copy2(project_path, backup_path)
    print(f"✓ Backed up project file to {backup_path}")
    return backup_path


def read_project_file():
    """Read the project.pbxproj file."""
    project_path = "hamrah-ios.xcodeproj/project.pbxproj"
    with open(project_path, 'r', encoding='utf-8') as f:
        return f.read()


def write_project_file(content):
    """Write the updated project.pbxproj file."""
    project_path = "hamrah-ios.xcodeproj/project.pbxproj"
    with open(project_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ Updated project.pbxproj file")


def generate_uuid():
    """Generate a unique identifier for Xcode project elements."""
    return uuid.uuid4().hex[:24].upper()


def fix_shareextension_target_settings(content):
    """Fix the ShareExtension target build settings."""

    # Find the HamrahShare target configuration sections
    debug_config_pattern = r'(5FEXTDBG0001[^}]+buildSettings\s*=\s*{)([^}]+)(};)'
    release_config_pattern = r'(5FEXTREL0001[^}]+buildSettings\s*=\s*{)([^}]+)(};)'

    # Define the correct build settings for ShareExtension
    shareext_settings = '''
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
				TARGETED_DEVICE_FAMILY = "1,2";'''

    # Debug configuration for ShareExtension
    debug_settings = shareext_settings + '''
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";'''

    # Release configuration for ShareExtension
    release_settings = shareext_settings + '''
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;'''

    # Replace debug configuration
    content = re.sub(
        debug_config_pattern,
        r'\1' + debug_settings + '\n\t\t\t' + r'\3',
        content,
        flags=re.DOTALL
    )

    # Replace release configuration
    content = re.sub(
        release_config_pattern,
        r'\1' + release_settings + '\n\t\t\t' + r'\3',
        content,
        flags=re.DOTALL
    )

    return content


def fix_file_references(content):
    """Fix file references to point to the correct ShareExtension paths."""

    # Update ShareExtension source file references
    patterns_replacements = [
        # Fix ShareViewController reference
        (r'hamrah-ios/ShareExtension/ShareViewController\.swift',
         'ShareExtension/Sources/ShareViewController.swift'),

        # Fix ShareExtension Info.plist reference
        (r'hamrah-ios/ShareExtension/Info\.plist',
         'ShareExtension/Sources/Info.plist'),

        # Fix ShareExtensionDataStack reference
        (r'hamrah-ios/ShareExtension/Utilities/ShareExtensionDataStack\.swift',
         'ShareExtension/Sources/Utilities/ShareExtensionDataStack.swift'),
    ]

    for pattern, replacement in patterns_replacements:
        content = re.sub(pattern, replacement, content)

    return content


def add_embedded_extension(content):
    """Add the ShareExtension as an embedded extension in the main app."""

    # Find the main app target section
    main_target_pattern = r'(3AC7BF752E4900DF00D7AA35[^{]+{[^}]+dependencies\s*=\s*\()([^)]*)\);'

    # Add HamrahShare as a dependency
    def add_dependency(match):
        dependencies = match.group(2).strip()
        if dependencies:
            # Add comma and new dependency
            return f"{match.group(1)}{dependencies},\n\t\t\t\t5FEXTDEP0001 /* PBXTargetDependency */,\n\t\t\t);"
        else:
            # First dependency
            return f"{match.group(1)}\n\t\t\t\t5FEXTDEP0001 /* PBXTargetDependency */,\n\t\t\t);"

    content = re.sub(main_target_pattern, add_dependency, content, flags=re.DOTALL)

    # Add the target dependency object if it doesn't exist
    if '5FEXTDEP0001' not in content:
        dependency_section = '''		5FEXTDEP0001 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = 5FEXTTGT0001 /* HamrahShare */;
			targetProxy = 5FEXTPRX0001 /* PBXContainerItemProxy */;
		};'''

        # Find the end of PBXTargetDependency section and add our dependency
        dependency_end_pattern = r'(/\* End PBXTargetDependency section \*/)'
        content = re.sub(dependency_end_pattern, dependency_section + '\n' + r'\1', content)

        # Add the container item proxy if it doesn't exist
        if '5FEXTPRX0001' not in content:
            proxy_section = '''		5FEXTPRX0001 /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = 3AC7BF6E2E4900DF00D7AA35 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = 5FEXTTGT0001;
			remoteInfo = HamrahShare;
		};'''

            # Find the end of PBXContainerItemProxy section and add our proxy
            proxy_end_pattern = r'(/\* End PBXContainerItemProxy section \*/)'
            content = re.sub(proxy_end_pattern, proxy_section + '\n' + r'\1', content)

    # Add embed app extensions build phase to main app
    embed_phase_pattern = r'(3AC7BF752E4900DF00D7AA35[^{]+{[^}]+buildPhases\s*=\s*\()([^)]*)\);'

    def add_embed_phase(match):
        phases = match.group(2).strip()
        if '5FEXTBED0001' not in phases:
            if phases:
                return f"{match.group(1)}{phases},\n\t\t\t\t5FEXTBED0001 /* Embed App Extensions */,\n\t\t\t);"
            else:
                return f"{match.group(1)}\n\t\t\t\t5FEXTBED0001 /* Embed App Extensions */,\n\t\t\t);"
        return match.group(0)

    content = re.sub(embed_phase_pattern, add_embed_phase, content, flags=re.DOTALL)

    # Add the embed app extensions build phase if it doesn't exist
    if '5FEXTBED0001' not in content:
        embed_section = '''		5FEXTBED0001 /* Embed App Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				5FEXTBLD0001 /* HamrahShare.appex in Embed App Extensions */,
			);
			name = "Embed App Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};'''

        # Find the end of PBXCopyFilesBuildPhase section and add our phase
        copy_end_pattern = r'(/\* End PBXCopyFilesBuildPhase section \*/)'
        content = re.sub(copy_end_pattern, embed_section + '\n' + r'\1', content)

        # Add the build file for embedding
        if '5FEXTBLD0001' not in content:
            build_file_section = '''		5FEXTBLD0001 /* HamrahShare.appex in Embed App Extensions */ = {
			isa = PBXBuildFile;
			fileRef = 5FEXTPRD0001 /* HamrahShare.appex */;
			settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); };
		};'''

            # Find the end of PBXBuildFile section and add our build file
            build_file_end_pattern = r'(/\* End PBXBuildFile section \*/)'
            content = re.sub(build_file_end_pattern, build_file_section + '\n' + r'\1', content)

    return content


def remove_shareextension_from_main_app_resources(content):
    """Remove ShareExtension Info.plist from main app's Copy Bundle Resources."""

    # Find and remove ShareExtension Info.plist from main app resources
    shareext_info_pattern = r'\s*[A-F0-9]+\s*/\*\s*Info\.plist\s*in\s*Resources\s*\*/,?\s*\n'
    content = re.sub(shareext_info_pattern, '', content)

    # Also remove references to ShareExtension directory from main app resources
    shareext_dir_pattern = r'\s*[A-F0-9]+\s*/\*\s*ShareExtension\s*in\s*Resources\s*\*/,?\s*\n'
    content = re.sub(shareext_dir_pattern, '', content)

    return content


def fix_file_system_sync_groups(content):
    """Fix the file system synchronized groups to exclude ShareExtension from main app."""

    # Update the main app's file system sync group to exclude ShareExtension
    sync_group_pattern = r'(5FMAINGRP0001[^{]+{[^}]+exceptions\s*=\s*\([^)]*membershipExceptions\s*=\s*\()([^)]*)\);'

    def update_exceptions(match):
        exceptions = match.group(2).strip()
        if 'ShareExtension' not in exceptions:
            if exceptions:
                return f"{match.group(1)}{exceptions},\n\t\t\t\t\"ShareExtension\",\n\t\t\t);"
            else:
                return f"{match.group(1)}\n\t\t\t\t\"ShareExtension\",\n\t\t\t);"
        return match.group(0)

    content = re.sub(sync_group_pattern, update_exceptions, content, flags=re.DOTALL)

    return content


def main():
    """Main function to fix the Xcode project."""
    print("🔧 Fixing Xcode project configuration for ShareExtension...")

    # Change to project directory
    if not os.path.exists("hamrah-ios.xcodeproj"):
        print("❌ Error: hamrah-ios.xcodeproj not found. Run this script from the project root.")
        return False

    try:
        # Backup the project file
        backup_project()

        # Read the current project file
        print("📖 Reading project configuration...")
        content = read_project_file()

        # Apply fixes
        print("🔨 Fixing ShareExtension target settings...")
        content = fix_shareextension_target_settings(content)

        print("🔗 Fixing file references...")
        content = fix_file_references(content)

        print("📦 Adding ShareExtension as embedded extension...")
        content = add_embedded_extension(content)

        print("🗑️  Removing ShareExtension resources from main app...")
        content = remove_shareextension_from_main_app_resources(content)

        print("📁 Fixing file system sync groups...")
        content = fix_file_system_sync_groups(content)

        # Write the updated project file
        write_project_file(content)

        print("\n✅ Successfully fixed Xcode project configuration!")
        print("\nNext steps:")
        print("1. Open the project in Xcode")
        print("2. Clean the build folder (Cmd+Shift+K)")
        print("3. Build the project (Cmd+B)")
        print("4. Test the share extension by:")
        print("   a. Running the app on a device/simulator")
        print("   b. Opening Safari and sharing a webpage")
        print("   c. Look for 'Hamrah Share' in the share sheet")

        return True

    except Exception as e:
        print(f"❌ Error fixing project: {e}")
        print("Restoring backup...")
        if os.path.exists("hamrah-ios.xcodeproj/project.pbxproj.backup"):
            shutil.copy2("hamrah-ios.xcodeproj/project.pbxproj.backup", "hamrah-ios.xcodeproj/project.pbxproj")
            print("✓ Backup restored")
        return False


if __name__ == "__main__":
    main()
