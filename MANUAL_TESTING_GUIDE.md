# Manual Testing Guide: Face ID Authentication on App Launch

## Prerequisites

1. **iOS Device with Face ID**: iPhone X or later with Face ID hardware
2. **Face ID Enabled in Device Settings**: Settings → Face ID & Passcode → Enable Face ID
3. **App Built and Installed**: The Hamrah iOS app with Face ID integration

## Testing Scenarios

### Scenario 1: First Time User (No Face ID Required)
**Expected Behavior**: Normal login flow, no Face ID prompt

**Steps:**
1. Launch the app (fresh install)
2. **Expected**: See the normal login screen (`NativeLoginView`)
3. Sign in with Apple ID, Google, or Passkey
4. **Expected**: Successfully authenticated, see main content (`ContentView`)

### Scenario 2: Enable Face ID After Login
**Expected Behavior**: Face ID gets enabled for future launches

**Steps:**
1. After logging in (Scenario 1), navigate to My Account (person icon)
2. Look for biometric authentication settings
3. Enable Face ID/biometric authentication
4. **Expected**: Face ID enrollment prompt appears
5. Complete Face ID enrollment
6. **Expected**: Face ID is now enabled for the account

### Scenario 3: App Launch with Face ID Enabled (Success)
**Expected Behavior**: Face ID prompt appears automatically, success leads to main content

**Steps:**
1. Ensure Face ID is enabled (completed Scenario 2)
2. Close the app completely (swipe up, swipe up on app card to close)
3. Re-launch the app
4. **Expected**: `BiometricLaunchView` appears with "Unlock Hamrah" message
5. **Expected**: Face ID prompt appears automatically
6. Look at the camera and authenticate with Face ID
7. **Expected**: Authentication succeeds, main content (`ContentView`) appears

### Scenario 4: App Launch with Face ID Enabled (Failure)
**Expected Behavior**: Face ID prompt appears, failure leads to logout

**Steps:**
1. Ensure Face ID is enabled (completed Scenario 2)
2. Close the app completely
3. Re-launch the app
4. **Expected**: `BiometricLaunchView` appears with "Unlock Hamrah" message
5. **Expected**: Face ID prompt appears automatically
6. Cover the camera or look away to fail Face ID
7. **Expected**: Authentication fails, user gets logged out
8. **Expected**: Return to login screen (`NativeLoginView`)

### Scenario 5: Face ID Disabled (Bypass)
**Expected Behavior**: No Face ID prompt, direct access to content

**Steps:**
1. Log in to the app
2. Navigate to My Account and disable Face ID/biometric authentication
3. Close the app completely
4. Re-launch the app
5. **Expected**: No `BiometricLaunchView`, direct access to main content (`ContentView`)

### Scenario 6: Face ID Hardware Unavailable
**Expected Behavior**: Graceful fallback, no Face ID prompts

**Steps:**
1. Test on device without Face ID hardware (iPhone 8 or earlier)
2. Launch app and log in
3. **Expected**: No biometric authentication options in settings
4. Close and re-launch app
5. **Expected**: Direct access to content, no biometric prompts

## Visual Indicators to Look For

### BiometricLaunchView Elements
- **Icon**: Face ID icon (face outline)
- **Title**: "Unlock Hamrah"
- **Subtitle**: "Use Face ID to access your account"
- **Background**: App background color (adapts to light/dark mode)

### Face ID Prompt (System UI)
- **Native iOS Face ID prompt**: Appears automatically when `BiometricLaunchView` is shown
- **Camera activation**: Front-facing camera activates for Face ID scan
- **Success animation**: iOS provides native success/failure feedback

### Error States
- **Failed Authentication**: Error message appears in `BiometricLaunchView`
- **User Cancel**: Returns to login screen after logout
- **Hardware Issues**: Graceful fallback to normal authentication

## Debugging Tips

1. **Enable Debug Logging**: Check console output for biometric authentication logs
2. **Check Settings**: Verify Face ID is enabled in both device settings and app settings
3. **Clean Install**: Try fresh app install to test first-time user experience
4. **Simulator Limitations**: Face ID testing requires physical device, simulator has limited biometric simulation

## Expected Log Messages

When Face ID authentication is working correctly, you should see logs like:
- `✅ Biometric type available: Face ID`
- `✅ Biometric authentication successful`
- `🔐 Biometric authentication disabled` (when disabled)
- `⚠️ Biometrics not available: [reason]` (when hardware unavailable)

## Common Issues and Solutions

1. **No Face ID Prompt**: Check if Face ID is enabled in app settings and device settings
2. **Immediate Failure**: Verify Face ID is enrolled in device settings
3. **App Crashes**: Check for missing imports or compilation errors
4. **Wrong View Shown**: Verify authentication state and biometric settings are correctly configured