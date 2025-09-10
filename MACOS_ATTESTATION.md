# Enhanced macOS App Attestation

This document describes the enhanced macOS app attestation system implemented to provide stronger verification of API calls from the macOS version of the Hamrah app.

## Overview

While iOS has Apple's App Attestation framework (`DCAppAttestService`) providing cryptographic proof of app authenticity, macOS doesn't have an equivalent system. This implementation provides the strongest possible verification for macOS apps using available platform capabilities.

## Security Features

### 1. Code Signature Verification
- Uses macOS Security framework (`SecCode`) to verify app code signature
- Validates signing certificate chain
- Extracts and includes team identifier and certificate fingerprint
- Detects if the app has been tampered with

### 2. Notarization Verification
- Checks if the app is properly notarized by Apple using `spctl`
- Notarized apps have been scanned by Apple for malware
- Provides assurance the app came through Apple's distribution pipeline

### 3. System Integrity Checks
- Verifies System Integrity Protection (SIP) status
- Checks for system-level integrity indicators
- Provides context about the runtime environment security

### 4. Cryptographic Attestation Tokens
- Generates P256 ECDSA key pairs stored in Keychain
- Creates signed attestation tokens for each request
- Falls back to enhanced hash-based tokens if cryptographic keys unavailable
- Includes challenge data to prevent replay attacks

### 5. Bundle Integrity
- Validates app bundle metadata consistency
- Includes version and build information
- Detects potential app replacement attacks

## Implementation Details

### Headers Generated

The enhanced attestation system generates the following headers:

```
X-Platform: macOS
X-App-Bundle-ID: app.hamrah.macos
X-App-Version: 1.0.0
X-App-Build: 1
X-App-Attestation-Mode: enhanced
X-App-Attestation-Token: <cryptographic-or-enhanced-hash-token>
X-App-Code-Signature-Status: valid|invalid
X-App-Notarization-Status: notarized|not-notarized|unknown
X-App-System-Integrity: sip-enabled,system-intact
X-App-Timestamp: <unix-timestamp>
X-App-Team-ID: <apple-team-id> (if available)
X-App-Cert-Fingerprint: <certificate-hash> (if available)
```

### Attestation Token Format

#### Cryptographic Mode (Preferred)
When P256 keys are available:
```json
{
  "payload": "<base64-encoded-json>",
  "signature": "<base64-encoded-signature>"
}
```

Where payload contains:
```json
{
  "keyId": "uuid",
  "challenge": "<base64-challenge>",
  "timestamp": 1234567890.123,
  "bundleId": "app.hamrah.macos"
}
```

#### Enhanced Hash Mode (Fallback)
When cryptographic keys unavailable:
```
enhanced:<sha256-hash-of-keyid:challenge:timestamp>
```

### Backend Integration

Backends can detect and handle enhanced macOS attestation:

```javascript
const attestationMode = headers['x-app-attestation-mode'];

switch(attestationMode) {
  case 'enhanced':
    // Strong macOS attestation - verify signatures, check certificates
    return verifyEnhancedMacOSAttestation(headers);
  
  case 'none':
    // Legacy basic mode - minimal trust
    return verifyBasicHeaders(headers);
    
  default:
    // iOS app attestation - highest trust
    return verifyiOSAppAttestation(headers);
}
```

## Security Model

### Trust Levels
1. **iOS App Attestation** (Highest) - Hardware-backed cryptographic proof
2. **Enhanced macOS Attestation** (Strong) - Multi-layer software verification
3. **Basic macOS Headers** (Minimal) - Metadata only

### Threat Mitigation
- **App Replacement**: Code signature and notarization verification
- **Runtime Tampering**: Bundle integrity and system checks
- **Replay Attacks**: Dynamic challenge-response tokens
- **Credential Theft**: Keychain-backed key storage
- **Environment Spoofing**: System integrity validation

### Limitations
- Not hardware-backed like iOS App Attestation
- Vulnerable to sophisticated runtime modification
- Relies on macOS security infrastructure integrity
- Can't prevent determined attacker with admin access

## Usage

The enhanced attestation is automatically used when running on macOS. No code changes required in `SecureAPIService` or other components - the same interface is maintained.

### Initialization
```swift
// Initialize after successful authentication
await SecureAPIService.shared.initializeAttestation(accessToken: token)
```

### Automatic Integration
```swift
// Headers automatically added to all API requests
let response = try await SecureAPIService.shared.get(
    endpoint: "/api/user/profile",
    accessToken: token,
    responseType: UserProfile.self
)
```

## Testing

Comprehensive test suite covers:
- Header generation and format validation
- Code signature verification scenarios
- Attestation token generation and verification
- Error handling and fallback modes
- Performance characteristics
- Backward compatibility

Run tests:
```bash
# iOS/macOS specific tests
xcodebuild test -scheme hamrah-ios -destination 'platform=macOS'
```

## Deployment Considerations

### App Store Distribution
- Code signing and notarization automatically handled
- Enhanced attestation works out of the box
- All security checks will pass for store-distributed apps

### Direct Distribution
- Must be properly code signed and notarized
- Self-signed apps will show `invalid` code signature status
- Backend should handle accordingly based on security requirements

### Development Builds
- May not be notarized (development certificates)
- Code signature verification may fail
- Fallback modes ensure functionality is maintained

## Backend Verification

Recommended backend verification flow:

1. **Check Platform**: Verify `X-Platform: macOS`
2. **Validate Mode**: Confirm `X-App-Attestation-Mode: enhanced`
3. **Verify Signature**: Check code signature status is `valid`
4. **Confirm Notarization**: Prefer `notarized` apps
5. **Validate Token**: Verify attestation token signature/hash
6. **Check Timestamp**: Ensure request is recent
7. **Trust Decision**: Make authorization decision based on verification results

Example verification logic:
```python
def verify_macos_attestation(headers):
    if headers.get('x-app-attestation-mode') != 'enhanced':
        return False, "Not enhanced attestation"
    
    if headers.get('x-app-code-signature-status') != 'valid':
        return False, "Invalid code signature"
    
    # Verify attestation token
    token = headers.get('x-app-attestation-token')
    if not verify_attestation_token(token, challenge):
        return False, "Invalid attestation token"
    
    # Additional checks...
    return True, "Attestation verified"
```

## Future Enhancements

Potential improvements as macOS platform evolves:
- Hardware security module integration when available
- Secure Enclave usage if supported
- Enhanced system attestation APIs
- Integration with macOS Monterey+ security features
- Remote attestation protocols

## Conclusion

This enhanced macOS attestation provides significantly stronger app verification than basic metadata while maintaining transparency about platform differences. It leverages all available macOS security infrastructure to provide the best possible verification short of hardware-backed attestation.

Backends can trust enhanced macOS attestation for most use cases while still differentiating from the stronger guarantees provided by iOS App Attestation.