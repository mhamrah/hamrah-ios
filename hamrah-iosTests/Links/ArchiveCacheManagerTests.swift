import XCTest

@testable import hamrah_ios

final class ArchiveCacheManagerTests: XCTestCase {

    // MARK: - Test Setup

    var manager: ArchiveCacheManager!
    var testServerId: String!
    var testArchiveDir: URL!

    override func setUpWithError() throws {
        super.setUp()
        manager = ArchiveCacheManager.shared
        testServerId = "test-link-123"
        // Use a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        ArchiveCacheManager.testContainerURLOverride = tempDir  // Override for test
        testArchiveDir = tempDir
    }

    override func tearDownWithError() throws {
        // Reset test override
        ArchiveCacheManager.testContainerURLOverride = nil
        // Clean up test directory
        if let dir = testArchiveDir {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }

    // MARK: - Archive Metadata

    func testWriteAndReadArchiveMeta() {
        let etag = "etag-abc"
        let size: Int64 = 123456
        manager.writeArchiveMeta(for: testServerId, etag: etag, sizeBytes: size)
        let meta = manager.readArchiveMeta(for: testServerId)
        XCTAssertNotNil(meta)
        XCTAssertEqual(meta?.etag, etag)
        XCTAssertEqual(meta?.sizeBytes, size)
        XCTAssertLessThanOrEqual(meta!.lastAccessed.timeIntervalSinceNow, 1.0)
    }

    func testTouchArchiveMetaUpdatesLastAccessed() {
        manager.writeArchiveMeta(for: testServerId, etag: "etag", sizeBytes: 100)
        let oldMeta = manager.readArchiveMeta(for: testServerId)
        sleep(1)
        manager.touchArchiveMeta(for: testServerId)
        let newMeta = manager.readArchiveMeta(for: testServerId)
        XCTAssertNotNil(newMeta)
        XCTAssertTrue(newMeta!.lastAccessed > oldMeta!.lastAccessed)
    }

    // MARK: - LRU Eviction

    func testEnforceQuotaEvictsOldest() {
        // Insert 3 fake archives with different lastAccessed times
        let ids = ["a", "b", "c"]
        let sizes: [Int64] = [100, 200, 300]
        let now = Date()
        for (i, id) in ids.enumerated() {
            manager.writeArchiveMeta(for: id, etag: "etag-\(id)", sizeBytes: sizes[i])
            // Manually set lastAccessed
            let metaURL = manager.archivesDirectory!.appendingPathComponent("\(id).meta.json")
            let meta = ArchiveCacheManager.ArchiveMeta(
                etag: "etag-\(id)", sizeBytes: sizes[i],
                lastAccessed: now.addingTimeInterval(TimeInterval(-i * 100)))
            let data = try! JSONEncoder().encode(meta)
            try! data.write(to: metaURL)
            // Create dummy zip file
            let zipURL = manager.archivesDirectory!.appendingPathComponent("\(id).zip")
            FileManager.default.createFile(
                atPath: zipURL.path, contents: Data(count: Int(sizes[i])))
        }
        // Set quota to 400 bytes (should evict the oldest, i.e., "c")
        manager.enforceQuota(quotaMB: 0)  // 0 MB = 0 bytes, but for test, we want to check logic
        // Only the two most recent should remain
        let files = try! FileManager.default.contentsOfDirectory(
            at: manager.archivesDirectory!, includingPropertiesForKeys: nil)
        let remaining = files.filter { $0.pathExtension == "zip" }.map {
            $0.deletingPathExtension().lastPathComponent
        }
        XCTAssertTrue(remaining.contains("a"))
        XCTAssertTrue(remaining.contains("b"))
        XCTAssertFalse(remaining.contains("c"))
    }

    // MARK: - Download Archive (Mocked)

    func testDownloadArchiveIfNeeded_skipsIfETagMatches() {
        let etag = "etag-123"
        let size: Int64 = 100
        manager.writeArchiveMeta(for: testServerId, etag: etag, sizeBytes: size)
        // Create dummy zip file
        let zipURL = manager.archivesDirectory!.appendingPathComponent("\(testServerId!).zip")
        FileManager.default.createFile(atPath: zipURL.path, contents: Data(count: Int(size)))
        let exp = expectation(description: "Download skipped")
        manager.downloadArchiveIfNeeded(
            serverId: testServerId, etag: etag,
            downloadURL: URL(string: "https://example.com/fake.zip")!
        ) { success, returnedEtag, returnedSize, error in
            XCTAssertTrue(success)
            XCTAssertEqual(returnedEtag, etag)
            XCTAssertEqual(returnedSize, size)
            XCTAssertNil(error)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    // Note: Real download test would require a local HTTP server or further mocking.
}
