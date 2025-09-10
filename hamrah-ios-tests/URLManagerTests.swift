//
//  URLManagerTests.swift
//  hamrah-ios-tests
//
//  Tests for URL saving and management functionality using Swift Testing framework
//

import Testing
import Foundation
import SwiftData
@testable import hamrah_ios

@MainActor
struct URLManagerTests {
    
    // MARK: - Helper method to create test setup
    private func createTestSetup() throws -> (URLManager, ModelContainer, ModelContext) {
        let schema = Schema([SavedURL.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        
        let urlManager = URLManager()
        urlManager.setModelContext(context)
        
        return (urlManager, container, context)
    }
    
    @Test("URL Manager saves valid URLs correctly")
    func testSaveValidURL() async throws {
        let (urlManager, _, context) = try createTestSetup()
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try context.fetch(fetchDescriptor)
        
        // Verify URL was saved
        #expect(savedURLs.count == 1)
        #expect(savedURLs.first?.url == testURL)
        #expect(savedURLs.first?.processingStatus == .pending)
        #expect(savedURLs.first?.syncStatus == .local)
    }
    
    @Test("URL Manager rejects invalid URLs")
    func testSaveInvalidURL() async throws {
        let (urlManager, _, context) = try createTestSetup()
        let invalidURL = "not-a-valid-url"
        
        // Save invalid URL
        urlManager.saveURL(invalidURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try context.fetch(fetchDescriptor)
        
        // Verify URL was not saved
        #expect(savedURLs.count == 0)
    }
    
    @Test("URL Manager prevents duplicate URL saving")
    func testSaveDuplicateURL() async throws {
        let (urlManager, _, context) = try createTestSetup()
        let testURL = "https://example.com"
        
        // Save URL twice
        urlManager.saveURL(testURL)
        urlManager.saveURL(testURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try context.fetch(fetchDescriptor)
        
        // Verify only one URL was saved
        #expect(savedURLs.count == 1)
    }
    
    @Test("URL Manager deletes URLs correctly")
    func testDeleteURL() async throws {
        let (urlManager, _, context) = try createTestSetup()
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch and delete URL
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try context.fetch(fetchDescriptor)
        #expect(savedURLs.count == 1)
        
        urlManager.deleteURL(savedURLs.first!)
        
        // Verify URL was deleted
        let remainingURLs = try context.fetch(fetchDescriptor)
        #expect(remainingURLs.count == 0)
    }
    
    @Test("SavedURL updates from backend correctly")
    func testUpdateFromBackend() async throws {
        let (urlManager, _, context) = try createTestSetup()
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch saved URL
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try context.fetch(fetchDescriptor)
        let savedURL = savedURLs.first!
        
        // Update from backend
        savedURL.updateFromBackend(
            title: "Example Title",
            summary: "Example summary",
            tags: ["test", "example"],
            processingStatus: .completed,
            backendId: "backend-uuid-123"
        )
        
        // Verify update
        #expect(savedURL.title == "Example Title")
        #expect(savedURL.summary == "Example summary")
        #expect(savedURL.tags == ["test", "example"])
        #expect(savedURL.processingStatus == .completed)
        #expect(savedURL.syncStatus == .synced)
        #expect(savedURL.backendId == "backend-uuid-123")
    }
    
    @Test("SavedURL initializes with correct defaults")
    func testSavedURLInitialization() async throws {
        let testURL = "https://example.com"
        let savedURL = SavedURL(url: testURL)
        
        #expect(savedURL.url == testURL)
        #expect(savedURL.title == nil)
        #expect(savedURL.summary == nil)
        #expect(savedURL.tags.isEmpty)
        #expect(savedURL.processingStatus == .pending)
        #expect(savedURL.syncStatus == .local)
        #expect(savedURL.backendId == nil)
    }
    
    @Test("Processing status enum has correct display names")
    func testProcessingStatusDisplayNames() async throws {
        #expect(ProcessingStatus.pending.displayName == "Pending")
        #expect(ProcessingStatus.processing.displayName == "Processing")
        #expect(ProcessingStatus.completed.displayName == "Ready")
        #expect(ProcessingStatus.failed.displayName == "Failed")
    }
    
    @Test("Sync status enum has correct display names")
    func testSyncStatusDisplayNames() async throws {
        #expect(SyncStatus.local.displayName == "Local Only")
        #expect(SyncStatus.syncing.displayName == "Syncing")
        #expect(SyncStatus.synced.displayName == "Synced")
        #expect(SyncStatus.syncFailed.displayName == "Sync Failed")
    }
    
    @Test("Processing status isProcessing flag works correctly")
    func testProcessingStatusIsProcessing() async throws {
        #expect(ProcessingStatus.pending.isProcessing == true)
        #expect(ProcessingStatus.processing.isProcessing == true)
        #expect(ProcessingStatus.completed.isProcessing == false)
        #expect(ProcessingStatus.failed.isProcessing == false)
    }
    
    @Test("Sync status needsSync flag works correctly")
    func testSyncStatusNeedsSync() async throws {
        #expect(SyncStatus.local.needsSync == true)
        #expect(SyncStatus.syncing.needsSync == false)
        #expect(SyncStatus.synced.needsSync == false)
        #expect(SyncStatus.syncFailed.needsSync == true)
    }
}

// MARK: - API Response Model Tests

struct URLManagerAPITests {
    
    @Test("URLSubmissionResponse decodes correctly")
    func testURLSubmissionResponseDecoding() async throws {
        let jsonData = """
        {
            "success": true,
            "id": "backend-uuid-123",
            "title": "Example Title",
            "summary": "Example summary",
            "tags": ["tag1", "tag2"],
            "processingStatus": "pending"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(URLSubmissionResponse.self, from: jsonData)
        
        #expect(response.success == true)
        #expect(response.id == "backend-uuid-123")
        #expect(response.title == "Example Title")
        #expect(response.summary == "Example summary")
        #expect(response.tags == ["tag1", "tag2"])
        #expect(response.processingStatus == "pending")
    }
    
    @Test("URLDetailResponse decodes correctly")
    func testURLDetailResponseDecoding() async throws {
        let jsonData = """
        {
            "success": true,
            "id": "backend-uuid-456",
            "url": "https://example.com",
            "title": "Detailed Title",
            "summary": "Detailed summary",
            "tags": ["detail", "test"],
            "processingStatus": "completed",
            "createdAt": "2024-01-01T12:00:00Z"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(URLDetailResponse.self, from: jsonData)
        
        #expect(response.success == true)
        #expect(response.id == "backend-uuid-456")
        #expect(response.url == "https://example.com")
        #expect(response.title == "Detailed Title")
        #expect(response.summary == "Detailed summary")
        #expect(response.tags == ["detail", "test"])
        #expect(response.processingStatus == "completed")
        #expect(response.createdAt == "2024-01-01T12:00:00Z")
    }
    
    @Test("URLSubmissionResponse handles error response")
    func testURLSubmissionResponseError() async throws {
        let jsonData = """
        {
            "success": false,
            "error": "Invalid URL format"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(URLSubmissionResponse.self, from: jsonData)
        
        #expect(response.success == false)
        #expect(response.error == "Invalid URL format")
        #expect(response.id == nil)
    }
}