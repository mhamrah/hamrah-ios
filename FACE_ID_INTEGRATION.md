# Face ID Authentication on App Launch

## Overview
The Hamrah iOS app now supports Face ID authentication when the app is opened. This feature ensures that users with Face ID enabled must authenticate via biometrics before accessing the app content.

## Implementation

### Key Components

1. **ProgressiveAuthView**: Modified to check for biometric authentication requirements on app launch
2. **BiometricLaunchView**: New view displayed during biometric authentication on launch  
3. **BiometricAuthManager**: Existing manager with `shouldRequireBiometricAuth()` and `authenticateForAppAccess()` methods

### Authentication Flow

When the app launches:

1. **User Not Authenticated**: Shows normal login screen (`NativeLoginView`)
2. **User Authenticated + Face ID Disabled**: Shows main content (`ContentView`) 
3. **User Authenticated + Face ID Enabled**: Shows biometric authentication screen (`BiometricLaunchView`)

### Biometric Authentication Process

```
App Launch
    ↓
ProgressiveAuthView.onAppear()
    ↓
checkBiometricAuthRequirement()
    ↓
authManager.isAuthenticated && biometricManager.shouldRequireBiometricAuth()
    ↓
Show BiometricLaunchView
    ↓
biometricManager.authenticateForAppAccess()
    ↓
Success: Show ContentView
Failed: Logout user (security measure)
```

### Security Considerations

- **Failed Authentication**: If Face ID authentication fails, the user is automatically logged out for security
- **Race Condition Protection**: Multiple biometric auth attempts are prevented with state guards
- **Fallback Handling**: Graceful degradation when biometric hardware is unavailable

### User Experience

- **Seamless Integration**: Face ID prompt appears automatically when needed
- **Visual Feedback**: Clear icon and messaging during authentication
- **Error Handling**: User-friendly error messages for failed attempts
- **Cancel Support**: Users can cancel authentication (results in logout)

## Configuration

Face ID authentication is automatically enabled when:
1. User has Face ID hardware available
2. User has enabled Face ID in app settings
3. User has an existing authenticated session

No additional configuration is required.

## Testing

The implementation includes comprehensive tests for:
- Biometric authentication requirements detection
- Authentication flow handling
- Error states and fallbacks
- Race condition prevention

## Files Modified

- `hamrah-ios/ProgressiveAuthView.swift`: Added biometric auth check on launch
- `hamrah-ios/BiometricLaunchView.swift`: New UI for biometric authentication (NEW)
- `hamrah-ios-tests/hamrahIOSTests.swift`: Added biometric launch auth tests

## Backward Compatibility

This feature is fully backward compatible:
- Existing authentication flows remain unchanged
- Users without Face ID continue to use the app normally
- No breaking changes to existing APIs or user settings