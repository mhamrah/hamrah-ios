import Foundation
import DeviceCheck
import CommonCrypto

class AppAttestationManager: ObservableObject {
    static let shared = AppAttestationManager()
    
    private let service = DCAppAttestService.shared
    private let keychain = KeychainManager.shared
    private let keyId = "hamrah_app_attest_key"
    private let baseURL = "https://api.hamrah.app"
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Generates attestation headers for API requests
    func generateAttestationHeaders(for challenge: Data) async throws -> [String: String] {
        let keyId = try await ensureAttestationKey()
        let assertion = try await generateAssertion(keyId: keyId, challenge: challenge)
        
        return [
            "X-iOS-App-Attest-Key": keyId,
            "X-iOS-App-Attest-Assertion": assertion.base64EncodedString(),
            "X-iOS-App-Bundle-ID": Bundle.main.bundleIdentifier ?? "app.hamrah.ios"
        ]
    }
    
    /// One-time setup: Generate key and get attestation from Apple
    func initializeAttestation(accessToken: String) async throws {
        print("🔐 Initializing iOS App Attestation...")
        
        // Step 1: Generate attestation key if needed
        let keyId = try await ensureAttestationKey()
        
        // Step 2: Check if we already have a valid attestation
        if keychain.retrieveString(for: "hamrah_attestation_completed") == "true" {
            print("✅ App Attestation already initialized")
            return
        }
        
        // Step 3: Get challenge from server
        let challenge = try await getAttestationChallenge(accessToken: accessToken)
        
        // Step 4: Generate attestation from Apple
        let attestationData = try await generateAttestation(keyId: keyId, challenge: challenge.challengeData)
        
        // Step 5: Submit attestation to server for verification
        try await submitAttestation(
            attestation: attestationData,
            keyId: keyId,
            challengeId: challenge.challengeId,
            accessToken: accessToken
        )
        
        // Mark as completed
        _ = keychain.store("true", for: "hamrah_attestation_completed")
        print("✅ iOS App Attestation initialization completed")
    }
    
    // MARK: - Private Implementation
    
    private func ensureAttestationKey() async throws -> String {
        // Check if we already have a key ID stored
        if let existingKeyId = keychain.retrieveString(for: keyId) {
            return existingKeyId
        }
        
        // Generate new key
        guard service.isSupported else {
            throw AttestationError.notSupported
        }
        
        let newKeyId = try await service.generateKey()
        
        // Store key ID securely
        guard keychain.store(newKeyId, for: keyId) else {
            throw AttestationError.keyStorageFailed
        }
        
        print("🔑 Generated new App Attestation key: \(newKeyId.prefix(8))...")
        return newKeyId
    }
    
    private func generateAttestation(keyId: String, challenge: Data) async throws -> Data {
        // Create hash of challenge as required by App Attest
        let challengeHash = sha256(challenge)
        
        return try await service.attestKey(keyId, clientDataHash: challengeHash)
    }
    
    private func generateAssertion(keyId: String, challenge: Data) async throws -> Data {
        // Create hash of challenge data
        let challengeHash = sha256(challenge)
        
        return try await service.generateAssertion(keyId, clientDataHash: challengeHash)
    }
    
    private func getAttestationChallenge(accessToken: String) async throws -> AttestationChallenge {
        let url = URL(string: "\(baseURL)/api/app-attestation/challenge")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? "app.hamrah.ios",
            "purpose": "attestation"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AttestationError.challengeRequestFailed
        }
        
        let challengeResponse = try JSONDecoder().decode(AttestationChallengeResponse.self, from: data)
        
        guard challengeResponse.success,
              let challengeBase64 = challengeResponse.challenge,
              let challengeData = Data(base64Encoded: challengeBase64) else {
            throw AttestationError.invalidChallenge
        }
        
        return AttestationChallenge(
            challengeId: challengeResponse.challengeId,
            challengeData: challengeData
        )
    }
    
    private func submitAttestation(attestation: Data, keyId: String, challengeId: String, accessToken: String) async throws {
        let url = URL(string: "\(baseURL)/api/app-attestation/verify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let body = [
            "attestation": attestation.base64EncodedString(),
            "keyId": keyId,
            "challengeId": challengeId,
            "bundleId": Bundle.main.bundleIdentifier ?? "app.hamrah.ios",
            "platform": "ios"
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AttestationError.verificationRequestFailed
        }
        
        let verificationResponse = try JSONDecoder().decode(AttestationVerificationResponse.self, from: data)
        
        guard httpResponse.statusCode == 200, verificationResponse.success else {
            throw AttestationError.verificationFailed(verificationResponse.error ?? "Unknown error")
        }
    }
    
    private func sha256(_ data: Data) -> Data {
        var hash = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        hash.withUnsafeMutableBytes { bytes in
            data.withUnsafeBytes { dataBytes in
                _ = CC_SHA256(dataBytes.baseAddress, CC_LONG(data.count), bytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return hash
    }
    
    // MARK: - Reset (for testing)
    
    func resetAttestation() {
        _ = keychain.delete(for: keyId)
        _ = keychain.delete(for: "hamrah_attestation_completed")
        print("🔄 App Attestation reset completed")
    }
}

// MARK: - Data Models

struct AttestationChallenge {
    let challengeId: String
    let challengeData: Data
}

struct AttestationChallengeResponse: Codable {
    let success: Bool
    let challenge: String?
    let challengeId: String
    let error: String?
}

struct AttestationVerificationResponse: Codable {
    let success: Bool
    let error: String?
}

// MARK: - Errors

enum AttestationError: LocalizedError {
    case notSupported
    case keyStorageFailed
    case challengeRequestFailed
    case invalidChallenge
    case verificationRequestFailed
    case verificationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "App Attestation is not supported on this device"
        case .keyStorageFailed:
            return "Failed to store attestation key securely"
        case .challengeRequestFailed:
            return "Failed to request attestation challenge"
        case .invalidChallenge:
            return "Invalid attestation challenge received"
        case .verificationRequestFailed:
            return "Failed to submit attestation for verification"
        case .verificationFailed(let error):
            return "Attestation verification failed: \(error)"
        }
    }
}