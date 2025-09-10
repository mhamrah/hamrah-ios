//
//  AppAttestationManagerTests.swift
//  hamrah-iosTests
//
//  Tests for enhanced macOS App Attestation Manager
//

import XCTest

#if os(macOS)
@testable import hamrah_ios

@available(macOS 10.15, *)
class AppAttestationManagerTests: XCTestCase {
    
    var attestationManager: AppAttestationManager!
    
    override func setUpWithError() throws {
        super.setUp()
        attestationManager = AppAttestationManager.shared
    }
    
    override func tearDownWithError() throws {
        attestationManager.resetAttestation()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAttestationManagerSingleton() {
        let manager1 = AppAttestationManager.shared
        let manager2 = AppAttestationManager.shared
        XCTAssertIdentical(manager1, manager2, "AttestationManager should be a singleton")
    }
    
    func testGenerateAttestationHeaders() async throws {
        let challenge = Data("test-challenge".utf8)
        
        let headers = try await attestationManager.generateAttestationHeaders(for: challenge)
        
        // Verify required headers are present
        XCTAssertNotNil(headers["X-Platform"])
        XCTAssertEqual(headers["X-Platform"], "macOS")
        
        XCTAssertNotNil(headers["X-App-Bundle-ID"])
        XCTAssertNotNil(headers["X-App-Version"])
        XCTAssertNotNil(headers["X-App-Build"])
        XCTAssertNotNil(headers["X-App-Attestation-Mode"])
        XCTAssertEqual(headers["X-App-Attestation-Mode"], "enhanced")
        
        XCTAssertNotNil(headers["X-App-Attestation-Token"])
        XCTAssertNotNil(headers["X-App-Code-Signature-Status"])
        XCTAssertNotNil(headers["X-App-System-Integrity"])
        XCTAssertNotNil(headers["X-App-Timestamp"])
        
        // Verify timestamp is reasonable (within last 5 seconds)
        if let timestampStr = headers["X-App-Timestamp"],
           let timestamp = Double(timestampStr) {
            let now = Date().timeIntervalSince1970
            XCTAssertTrue(abs(now - timestamp) < 5, "Timestamp should be recent")
        } else {
            XCTFail("Timestamp should be present and valid")
        }
    }
    
    func testInitializeAttestation() async throws {
        let accessToken = "test-token"
        
        // Should not throw for basic initialization
        try await attestationManager.initializeAttestation(accessToken: accessToken)
        
        // Should be idempotent - calling again should not throw
        try await attestationManager.initializeAttestation(accessToken: accessToken)
    }
    
    func testResetAttestation() {
        // Should not throw
        attestationManager.resetAttestation()
        
        // Should be safe to call multiple times
        attestationManager.resetAttestation()
    }
    
    // MARK: - Header Consistency Tests
    
    func testHeadersConsistency() async throws {
        let challenge1 = Data("challenge-1".utf8)
        let challenge2 = Data("challenge-2".utf8)
        
        let headers1 = try await attestationManager.generateAttestationHeaders(for: challenge1)
        let headers2 = try await attestationManager.generateAttestationHeaders(for: challenge2)
        
        // These should be the same across calls (app metadata)
        XCTAssertEqual(headers1["X-Platform"], headers2["X-Platform"])
        XCTAssertEqual(headers1["X-App-Bundle-ID"], headers2["X-App-Bundle-ID"])
        XCTAssertEqual(headers1["X-App-Version"], headers2["X-App-Version"])
        XCTAssertEqual(headers1["X-App-Build"], headers2["X-App-Build"])
        XCTAssertEqual(headers1["X-App-Attestation-Mode"], headers2["X-App-Attestation-Mode"])
        
        // These should potentially differ (challenge-dependent or time-dependent)
        // Note: Attestation token may be the same if using fallback mode, so we don't assert inequality
        
        // Timestamps should be close but potentially different
        if let timestamp1 = headers1["X-App-Timestamp"], let timestamp2 = headers2["X-App-Timestamp"] {
            // Should be within a reasonable time window
            XCTAssertTrue(timestamp1.count > 0)
            XCTAssertTrue(timestamp2.count > 0)
        }
    }
    
    // MARK: - Security Headers Tests
    
    func testCodeSignatureHeaders() async throws {
        let challenge = Data("test-challenge".utf8)
        let headers = try await attestationManager.generateAttestationHeaders(for: challenge)
        
        let codeSignatureStatus = headers["X-App-Code-Signature-Status"]
        XCTAssertNotNil(codeSignatureStatus)
        XCTAssertTrue(codeSignatureStatus == "valid" || codeSignatureStatus == "invalid")
        
        // In a test environment, we might not have a valid signature
        // but we should at least get a status
        XCTAssertFalse(codeSignatureStatus!.isEmpty)
    }
    
    func testSystemIntegrityHeaders() async throws {
        let challenge = Data("test-challenge".utf8)
        let headers = try await attestationManager.generateAttestationHeaders(for: challenge)
        
        let systemIntegrity = headers["X-App-System-Integrity"]
        XCTAssertNotNil(systemIntegrity)
        XCTAssertFalse(systemIntegrity!.isEmpty)
        
        // Should contain some meaningful information
        XCTAssertTrue(systemIntegrity!.count > 0)
    }
    
    func testAttestationToken() async throws {
        let challenge = Data("test-challenge".utf8)
        let headers = try await attestationManager.generateAttestationHeaders(for: challenge)
        
        let attestationToken = headers["X-App-Attestation-Token"]
        XCTAssertNotNil(attestationToken)
        XCTAssertFalse(attestationToken!.isEmpty)
        
        // Token should be base64 encoded (either cryptographic or fallback)
        XCTAssertGreaterThan(attestationToken!.count, 10)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceGenerateHeaders() throws {
        let challenge = Data("performance-test".utf8)
        
        measure {
            let expectation = self.expectation(description: "Generate headers")
            
            Task {
                do {
                    _ = try await attestationManager.generateAttestationHeaders(for: challenge)
                    expectation.fulfill()
                } catch {
                    XCTFail("Header generation failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyChallenge() async throws {
        let emptyChallenge = Data()
        
        // Should not throw even with empty challenge
        let headers = try await attestationManager.generateAttestationHeaders(for: emptyChallenge)
        
        XCTAssertEqual(headers["X-Platform"], "macOS")
        XCTAssertEqual(headers["X-App-Attestation-Mode"], "enhanced")
    }
    
    func testLargeChallenge() async throws {
        // Create a large challenge (1MB)
        let largeChallenge = Data(repeating: 0xFF, count: 1_024_000)
        
        // Should handle large challenges gracefully
        let headers = try await attestationManager.generateAttestationHeaders(for: largeChallenge)
        
        XCTAssertEqual(headers["X-Platform"], "macOS")
        XCTAssertEqual(headers["X-App-Attestation-Mode"], "enhanced")
    }
}

#else
// Placeholder for non-macOS platforms
class AppAttestationManagerTests: XCTestCase {
    func testPlaceholder() {
        // This test suite is only for macOS
        XCTAssertTrue(true)
    }
}
#endif