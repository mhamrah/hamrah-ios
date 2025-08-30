# Hamrah iOS App

## Overview
Hamrah iOS is a native Swift application that provides secure authentication and user management, serving as a client to the hamrah-api backend. The app focuses on secure authentication flows including Apple Sign-In, Google Sign-In, and WebAuthn passkeys.

## Core Features

### Secure Authentication
- **Apple Sign-In**: Native iOS integration with Apple ID authentication
- **Google Sign-In**: OAuth 2.0 flow with Google accounts  
- **WebAuthn Passkeys**: Biometric authentication with Face ID/Touch ID
- **App Attestation**: iOS DeviceCheck integration to verify app authenticity

### Security Architecture
- **Keychain Storage**: Secure storage for tokens and sensitive data
- **App Attestation**: Validates authentic app requests to prevent tampering
- **Token Management**: Automatic refresh and secure storage of access/refresh tokens
- **TLS Pinning**: Certificate pinning for API communications (recommended)

## Technical Architecture

### Backend Integration
- **API Endpoint**: `https://api.hamrah.app/api/`
- **Protocol**: JSON over HTTPS
- **Authentication**: Bearer token with App Attestation headers
- **Related Projects**: 
  - API backend: `../hamrah-api` (Rust/Axum)
  - Web app: `../hamrah-app` (Qwik framework)

### Key Components
- **NativeAuthManager**: Main authentication coordinator
- **SecureAPIService**: Handles App Attestation and secure API calls  
- **TokenManager**: Manages access/refresh tokens in Keychain
- **BiometricAuthManager**: Handles Face ID/Touch ID authentication

### Authentication Flow
1. **OAuth Login**: Apple/Google OAuth handled natively in iOS
2. **Token Exchange**: OAuth tokens exchanged for hamrah-api access tokens
3. **App Attestation**: iOS App Attest service validates app authenticity
4. **Secure Storage**: Tokens stored in Keychain with biometric protection
5. **API Communication**: Authenticated API calls with attestation headers

### Data Strategy
- **API-First**: All data operations go through hamrah-api
- **Local Caching**: Minimal local storage for UI state only
- **Keychain Storage**: Secure storage for authentication tokens
- **No Local Database**: App relies entirely on hamrah-api for data persistence

## Development Guidelines

### Security Best Practices
- **Never store sensitive data in UserDefaults** - use Keychain only
- **Always include App Attestation headers** for API calls
- **Implement biometric authentication** for token access
- **Use certificate pinning** for API communications
- **Validate API responses** and handle errors gracefully

### Code Standards
- Follow iOS Human Interface Guidelines
- Use SwiftUI for modern UI development
- Implement proper error handling and user feedback
- Create unit tests for authentication flows
- Use Combine for reactive programming patterns

### Testing Strategy
- Unit tests for authentication managers
- Integration tests for API communication
- UI tests for authentication flows
- Security tests for token handling

### Performance
- Prioritize performance in all implementations