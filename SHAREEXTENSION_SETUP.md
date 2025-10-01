# Hamrah iOS ShareExtension Setup Guide

## Overview

This document explains the complete setup and configuration of the ShareExtension for the Hamrah iOS app. The ShareExtension allows users to save URLs directly from other apps (Safari, Chrome, etc.) to their Hamrah account through the iOS share sheet.

## Architecture

The ShareExtension follows the offline-first architecture principles:

- **Offline Storage**: URLs are saved locally using SwiftData in an App Group container
- **Background Sync**: The main app syncs saved URLs to the hamrah-api backend when online
- **Cross-Platform**: Works on both iOS and macOS with proper entitlements
- **Security**: Uses App Groups and Keychain sharing for secure data access

## File Structure

```
hamrah-ios/
├── ShareExtension/
│   └── Sources/
│       ├── ShareViewController.swift          # Main extension controller
│       ├── Info.plist                        # Extension configuration
│       ├── ShareExtension.entitlements       # App Groups & Keychain access
│       └── Utilities/
│           └── ShareExtensionDataStack.swift # SwiftData configuration
└── hamrah-ios/
    ├── Core/Models/Links/                     # Shared data models
    │   ├── LinkEntity.swift                  # Main link data model
    │   ├── TagEntity.swift                   # Tags for links
    │   ├── SyncCursor.swift                  # Sync state tracking
    │   └── UserPrefs.swift                   # User preferences
    └── hamrah-ios.entitlements               # Main app entitlements
```

## Key Components

### 1. ShareViewController.swift

The main entry point for the ShareExtension that:
- Uses `SLComposeServiceViewController` for iOS compatibility
- Extracts URLs and metadata from shared content
- Saves links to local SwiftData store
- Handles both new links and duplicate detection
- Provides user feedback and deep linking to main app

### 2. ShareExtensionDataStack.swift

Configures SwiftData for the extension:
- Uses App Group container (`group.app.hamrah.ios`)
- Shares data models with main app
- Provides isolated ModelContext for extension operations

### 3. Info.plist Configuration

Critical settings for share sheet integration:
```xml
<key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
<integer>1</integer>
<key>NSExtensionActivationSupportsURLWithMaxCount</key>
<integer>1</integer>
<key>NSExtensionActivationSupportsText</key>
<true/>
```

### 4. Entitlements

Both main app and extension share:
- **App Groups**: `group.app.hamrah.ios`
- **Keychain Access**: `$(AppIdentifierPrefix)app.hamrah.ios`

## Build Configuration

### Target Settings

**Bundle Identifier**: `app.hamrah.ios.ShareExtension`
**Deployment Target**: iOS 17.0, macOS 14.0
**Product Type**: App Extension
**Skip Install**: YES

### Key Build Settings

```
CODE_SIGN_ENTITLEMENTS = "ShareExtension/Sources/ShareExtension.entitlements"
CODE_SIGN_STYLE = Automatic
INFOPLIST_FILE = "ShareExtension/Sources/Info.plist"
PRODUCT_BUNDLE_IDENTIFIER = "app.hamrah.ios.ShareExtension"
SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"
```

### Dependencies

The ShareExtension target includes:
- ShareViewController.swift
- ShareExtensionDataStack.swift
- LinkEntity.swift (shared from main app)
- TagEntity.swift (shared from main app)
- SyncCursor.swift (shared from main app)
- UserPrefs.swift (shared from main app)

## Data Flow

### 1. URL Sharing Process

1. User taps share button in Safari/other app
2. iOS presents share sheet with "Hamrah Share" option
3. ShareViewController extracts URL and metadata
4. Extension saves to local SwiftData store with status "queued"
5. User sees confirmation and can optionally open main app

### 2. Sync Process

1. Main app launches and detects queued links
2. Background sync service uploads links to hamrah-api
3. Server returns canonical URLs and metadata
4. Local links updated with synced status
5. UI reflects successful save

### 3. Offline Behavior

- Extension works completely offline
- Links saved locally until internet available
- Main app handles all network operations
- Graceful degradation when backend unavailable

## Security Considerations

### App Groups

Enables secure data sharing between main app and extension:
```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.app.hamrah.ios</string>
</array>
```

### Keychain Access

Shared keychain access for authentication tokens:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)app.hamrah.ios</string>
</array>
```

### Token Validation

Extension checks for valid auth tokens:
- If token exists: Silent save operation
- If no token: Prompts to open main app for authentication

## Testing

### Manual Testing

1. **Basic Functionality**:
   - Share a URL from Safari
   - Verify "Hamrah Share" appears in share sheet
   - Confirm successful save message

2. **Duplicate Handling**:
   - Share the same URL twice
   - Verify save count increments
   - Check last saved timestamp updates

3. **Offline Operation**:
   - Disable internet connection
   - Share URLs to verify local storage
   - Re-enable internet and check sync

4. **Cross-Platform**:
   - Test on iOS simulator/device
   - Test on macOS (if applicable)

### Debug Tips

1. **Extension Not Appearing**:
   - Check Info.plist activation rules
   - Verify bundle identifier matches entitlements
   - Ensure extension is embedded in main app

2. **Data Not Syncing**:
   - Verify App Group identifier matches
   - Check SwiftData container path
   - Validate model schema compatibility

3. **Build Errors**:
   - Ensure all model files added to extension target
   - Check entitlements file paths
   - Verify code signing configuration

## Troubleshooting

### Common Issues

1. **"Multiple commands produce Info.plist"**
   - Exclude extension Info.plist from main app resources
   - Use GENERATE_INFOPLIST_FILE = NO for main app

2. **Extension missing from share sheet**
   - Rebuild and reinstall app completely
   - Check iOS Settings > Share Extensions
   - Verify activation rules in Info.plist

3. **Data not appearing in main app**
   - Confirm App Group container setup
   - Check SwiftData model compatibility
   - Verify background app refresh enabled

### Performance Optimization

1. **Fast Launch**:
   - Pre-extract input in viewDidLoad
   - Cache authentication state
   - Minimize SwiftData operations

2. **Memory Usage**:
   - Use lightweight data models in extension
   - Avoid loading large dependencies
   - Clean up resources promptly

## Best Practices

### Code Organization

- Keep extension code minimal and focused
- Share models but not UI components
- Use dependency injection for testability

### User Experience

- Provide clear feedback for save operations
- Handle errors gracefully with user-friendly messages
- Support both quick save and main app navigation

### Maintenance

- Keep extension and main app models in sync
- Test after each iOS update
- Monitor crash reports for extension-specific issues

## Future Enhancements

1. **Rich Metadata**: Extract and display page titles, descriptions
2. **Tag Support**: Allow users to add tags during save
3. **Bulk Operations**: Support saving multiple URLs at once
4. **Shortcuts Integration**: iOS Shortcuts app integration
5. **Widget Support**: Quick save from home screen widget

## Resources

- [Apple App Extension Programming Guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/)
- [Share Extension Documentation](https://developer.apple.com/documentation/social/slcomposeserviceviewcontroller)
- [App Groups Documentation](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

---

**Note**: This ShareExtension implementation follows iOS best practices and integrates seamlessly with the Hamrah app's offline-first architecture. All data flows through the established sync engine to maintain consistency and security.
