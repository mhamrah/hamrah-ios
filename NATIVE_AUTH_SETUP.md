# Native Authentication Setup for hamrahIOS

This guide will help you configure Apple Sign-In, Google Sign-In, and Passkeys for the Hamrah iOS app.

## 1. Apple Sign-In Setup

### Enable Sign In with Apple Capability
1. Open your Xcode project
2. Select your app target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability" 
5. Add "Sign In with Apple"

### Configure Apple Developer Account
1. Go to [Apple Developer Console](https://developer.apple.com/account)
2. Navigate to "Certificates, Identifiers & Profiles" > "Identifiers"
3. Select your App ID
4. Enable "Sign In with Apple" capability
5. Configure your primary App ID if prompted

## 2. Google Sign-In Setup

### Install Google Sign-In SDK
Add to your Xcode project:
1. File > Add Package Dependencies
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Select "Up to Next Major Version"
4. Add to your target

### Configure Google Services
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable "Google Sign-In API"
4. Go to "Credentials" > "Create Credentials" > "OAuth client ID"
5. Choose "iOS" application type
6. Add your bundle identifier: `app.hamrah.ios`
7. Download the `GoogleService-Info.plist` file
8. Add `GoogleService-Info.plist` to your Xcode project root

### Update Info.plist for Google Sign-In
Add URL schemes to your app's Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>hamrah.auth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>hamrah</string>
        </array>
    </dict>
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

Replace `YOUR_REVERSED_CLIENT_ID` with the `REVERSED_CLIENT_ID` from your `GoogleService-Info.plist`.

## 3. Passkeys Setup

### Enable Associated Domains
1. In Xcode, go to "Signing & Capabilities"
2. Add "Associated Domains" capability
3. Add domain: `webcredentials:localhost:5173` (for development)
4. For production, add: `webcredentials:hamrah.app`

### Configure WebAuthn Domain
Make sure your hamrah.app backend is configured with the correct domain for WebAuthn.

## 4. Backend Configuration

### Environment Variables
Set these in your hamrah.app backend:

```bash
# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id.googleusercontent.com

# Apple OAuth (if using web OAuth flow)
APPLE_CLIENT_ID=your.app.bundle.id
APPLE_TEAM_ID=your-team-id
APPLE_KEY_ID=your-key-id
APPLE_CERTIFICATE=your-private-key-pem
```

### Update CORS Settings
Ensure your backend allows requests from the iOS app. Update your CORS configuration to include:
- `hamrah://` scheme for OAuth callbacks
- iOS app bundle identifier

## 5. Test the Setup

### Development Testing
1. Start your hamrah.app development server:
   ```bash
   cd hamrah-app
   pnpm dev
   ```

2. Build and run your iOS app in simulator or device

3. Try each authentication method:
   - **Apple Sign-In**: Should show Apple's native sign-in UI
   - **Google Sign-In**: Should show Google's native sign-in UI  
   - **Passkeys**: Should show Face ID/Touch ID prompt

### Production Setup
1. Deploy your hamrah.app backend with production environment variables
2. Update the `baseURL` in `NativeAuthManager.swift` to point to your production server
3. Update Associated Domains to use your production domain
4. Test on physical devices with production Apple ID and Google accounts

## 6. Security Considerations

- **Never commit** your `GoogleService-Info.plist` or any OAuth secrets to version control
- Use different OAuth clients for development and production
- Regularly rotate your OAuth client secrets
- Monitor authentication logs for suspicious activity
- Test on both simulator and physical devices

## 7. Troubleshooting

### Apple Sign-In Issues
- Ensure your Apple Developer account has "Sign In with Apple" enabled
- Check that your app's bundle ID matches the one in Apple Developer Console
- Verify the capability is added to your Xcode project

### Google Sign-In Issues
- Verify `GoogleService-Info.plist` is added to your project
- Check that URL schemes are correctly configured
- Ensure Google Sign-In API is enabled in Google Cloud Console

### Passkey Issues
- Verify Associated Domains are configured correctly
- Check that WebAuthn is working in your web backend
- Ensure the domain matches between iOS and backend configuration

### Backend Issues
- Check that the `/api/auth/native` endpoint is working
- Verify environment variables are set correctly
- Monitor server logs for authentication errors
- Test token verification with actual tokens

## 8. Next Steps

Once authentication is working:
1. Implement user profile management
2. Add biometric security for app access
3. Implement account linking between different auth methods
4. Add multi-device synchronization
5. Implement secure data storage and encryption