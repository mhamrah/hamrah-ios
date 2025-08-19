# Google Sign-In Setup for iOS

## Add Google Sign-In Package

1. Open `hamrahIOS.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Enter the URL: `https://github.com/google/GoogleSignIn-iOS`
4. Choose **Up to Next Major Version** with version `8.0.0`
5. Click **Add Package**
6. Select **GoogleSignIn** and click **Add Package**

## Alternative: Add via Swift Package Manager

If you prefer command line:

```bash
# From the hamrahIOS directory
swift package init --type executable
# Then add to Package.swift dependencies
```

## Configure Google Services

1. Download `GoogleService-Info.plist` from [Firebase Console](https://console.firebase.google.com)
2. Add it to your Xcode project (drag and drop into Xcode)
3. Make sure it's added to the target

## Update Info.plist

Add the following URL scheme to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>GoogleSignIn</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_REVERSED_CLIENT_ID` with the value from your `GoogleService-Info.plist`.

## Initialize in App

The `NativeAuthManager.swift` already includes the Google Sign-In initialization code.

## Test the Integration

1. Build the project to ensure no compilation errors
2. Test on a physical device (Google Sign-In requires a physical device for full testing)