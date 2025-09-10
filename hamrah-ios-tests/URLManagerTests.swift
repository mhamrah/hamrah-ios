//
//  URLManagerTests.swift
//  hamrah-ios-tests
//
//  Tests for URL saving and management functionality
//

import XCTest
import SwiftData
@testable import hamrah_ios

final class URLManagerTests: XCTestCase {
    var urlManager: URLManager!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    @MainActor
    override func setUp() async throws {
        // Create in-memory model container for testing
        let schema = Schema([SavedURL.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        
        urlManager = URLManager()
        urlManager.setModelContext(modelContext)
    }
    
    override func tearDown() async throws {
        urlManager = nil
        modelContext = nil
        modelContainer = nil
    }
    
    @MainActor
    func testSaveValidURL() throws {
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try modelContext.fetch(fetchDescriptor)
        
        // Verify URL was saved
        XCTAssertEqual(savedURLs.count, 1)
        XCTAssertEqual(savedURLs.first?.url, testURL)
        XCTAssertEqual(savedURLs.first?.processingStatus, .pending)
        XCTAssertEqual(savedURLs.first?.syncStatus, .local)
    }
    
    @MainActor
    func testSaveInvalidURL() throws {
        let invalidURL = "not-a-valid-url"
        
        // Save invalid URL
        urlManager.saveURL(invalidURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try modelContext.fetch(fetchDescriptor)
        
        // Verify URL was not saved
        XCTAssertEqual(savedURLs.count, 0)
    }
    
    @MainActor
    func testSaveDuplicateURL() throws {
        let testURL = "https://example.com"
        
        // Save URL twice
        urlManager.saveURL(testURL)
        urlManager.saveURL(testURL)
        
        // Fetch saved URLs
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try modelContext.fetch(fetchDescriptor)
        
        // Verify only one URL was saved
        XCTAssertEqual(savedURLs.count, 1)
    }
    
    @MainActor
    func testDeleteURL() throws {
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch and delete URL
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(savedURLs.count, 1)
        
        urlManager.deleteURL(savedURLs.first!)
        
        // Verify URL was deleted
        let remainingURLs = try modelContext.fetch(fetchDescriptor)
        XCTAssertEqual(remainingURLs.count, 0)
    }
    
    @MainActor
    func testUpdateFromBackend() throws {
        let testURL = "https://example.com"
        
        // Save URL
        urlManager.saveURL(testURL)
        
        // Fetch saved URL
        let fetchDescriptor = FetchDescriptor<SavedURL>()
        let savedURLs = try modelContext.fetch(fetchDescriptor)
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
        XCTAssertEqual(savedURL.title, "Example Title")
        XCTAssertEqual(savedURL.summary, "Example summary")
        XCTAssertEqual(savedURL.tags, ["test", "example"])
        XCTAssertEqual(savedURL.processingStatus, .completed)
        XCTAssertEqual(savedURL.syncStatus, .synced)
        XCTAssertEqual(savedURL.backendId, "backend-uuid-123")
    }
}