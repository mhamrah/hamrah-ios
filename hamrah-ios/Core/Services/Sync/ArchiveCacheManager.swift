import Foundation

/// Manages downloading, caching, and eviction of archive assets in the App Group container.
/// Handles ETag validation, LRU eviction, and quota enforcement.
final class ArchiveCacheManager {
    static let shared = ArchiveCacheManager()

    // MARK: - Configuration

    /// App Group identifier for shared storage
    static let appGroupId = "group.app.hamrah.ios"
    /// Test hook: when set, archivesDirectory will use this container URL instead of the App Group container.
    static var testContainerURLOverride: URL?

    /// Subdirectory for archive zips
    static let archivesSubdir = "Caches/Archives"

    /// Default cache quota in MB (can be overridden by DevicePrefs)
    static let defaultQuotaMB: Int = 512

    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "ArchiveCacheManager.io")

    // MARK: - Paths

    /// Returns the URL to the archive cache directory in the App Group container.
    var archivesDirectory: URL? {
        // Test override for unit tests: use the provided container URL directly.
        if let override = Self.testContainerURLOverride {
            let dir = override.appendingPathComponent(Self.archivesSubdir, isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
        guard
            let container = fileManager.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupId)
        else {
            return nil
        }
        let dir = container.appendingPathComponent(Self.archivesSubdir, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Returns the URL for a specific archive zip by serverId.
    func archiveZipURL(for serverId: String) -> URL? {
        archivesDirectory?.appendingPathComponent("\(serverId).zip")
    }

    // MARK: - Download & ETag

    /// Downloads the archive zip for a given serverId if ETag is new.
    /// - Parameters:
    ///   - serverId: The server-side unique ID for the link.
    ///   - etag: The ETag from the server (for cache validation).
    ///   - downloadURL: The URL to download the archive from.
    ///   - completion: Called with (success, newETag, sizeBytes, error).
    func downloadArchiveIfNeeded(
        serverId: String,
        etag: String?,
        downloadURL: URL,
        completion: @escaping (Bool, String?, Int64?, Error?) -> Void
    ) {
        ioQueue.async {
            guard let zipURL = self.archiveZipURL(for: serverId) else {
                completion(
                    false, nil, nil,
                    NSError(
                        domain: "ArchiveCacheManager", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No archive directory"]))
                return
            }

            // Check if file exists and ETag matches
            if let etag = etag,
                let meta = self.readArchiveMeta(for: serverId),
                meta.etag == etag,
                self.fileManager.fileExists(atPath: zipURL.path)
            {
                // Already up to date
                completion(true, etag, meta.sizeBytes, nil)
                return
            }

            // Download the archive (simple URLSession, no auth for demo)
            var request = URLRequest(url: downloadURL)
            if let etag = etag {
                request.addValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            let task = URLSession.shared.downloadTask(with: request) { tempURL, response, error in
                if let error = error {
                    completion(false, nil, nil, error)
                    return
                }
                guard let tempURL = tempURL,
                    let httpResp = response as? HTTPURLResponse,
                    httpResp.statusCode == 200
                else {
                    completion(
                        false, nil, nil,
                        NSError(
                            domain: "ArchiveCacheManager", code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Download failed or not modified"]
                        ))
                    return
                }
                // Move file to cache
                do {
                    if self.fileManager.fileExists(atPath: zipURL.path) {
                        try self.fileManager.removeItem(at: zipURL)
                    }
                    try self.fileManager.moveItem(at: tempURL, to: zipURL)
                    let attrs = try self.fileManager.attributesOfItem(atPath: zipURL.path)
                    let size = attrs[.size] as? Int64 ?? 0
                    let newEtag = httpResp.allHeaderFields["ETag"] as? String
                    self.writeArchiveMeta(for: serverId, etag: newEtag, sizeBytes: size)
                    completion(true, newEtag, size, nil)
                } catch {
                    completion(false, nil, nil, error)
                }
            }
            task.resume()
        }
    }

    // MARK: - Archive Metadata

    struct ArchiveMeta: Codable {
        let etag: String?
        let sizeBytes: Int64
        let lastAccessed: Date
    }

    /// Reads archive metadata for a given serverId.
    func readArchiveMeta(for serverId: String) -> ArchiveMeta? {
        guard let dir = archivesDirectory else { return nil }
        let metaURL = dir.appendingPathComponent("\(serverId).meta.json")
        guard let data = try? Data(contentsOf: metaURL) else { return nil }
        return try? JSONDecoder().decode(ArchiveMeta.self, from: data)
    }

    /// Writes archive metadata for a given serverId.
    func writeArchiveMeta(for serverId: String, etag: String?, sizeBytes: Int64) {
        guard let dir = archivesDirectory else { return }
        let metaURL = dir.appendingPathComponent("\(serverId).meta.json")
        let meta = ArchiveMeta(etag: etag, sizeBytes: sizeBytes, lastAccessed: Date())
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: metaURL)
        }
    }

    /// Updates last accessed time for LRU.
    func touchArchiveMeta(for serverId: String) {
        guard let meta = readArchiveMeta(for: serverId) else { return }
        writeArchiveMeta(for: serverId, etag: meta.etag, sizeBytes: meta.sizeBytes)
    }

    // MARK: - LRU Eviction

    /// Enforces the archive cache quota (in MB), evicting least recently used archives if needed.
    func enforceQuota(quotaMB: Int = defaultQuotaMB) {
        ioQueue.async {
            guard let dir = self.archivesDirectory else { return }
            let files =
                (try? self.fileManager.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                    options: [])) ?? []
            var metas: [(serverId: String, meta: ArchiveMeta, zipURL: URL, metaURL: URL)] = []
            var totalBytes: Int64 = 0

            for file in files where file.pathExtension == "meta.json" {
                let serverId = file.deletingPathExtension().lastPathComponent
                guard let meta = self.readArchiveMeta(for: serverId),
                    let zipURL = self.archiveZipURL(for: serverId),
                    self.fileManager.fileExists(atPath: zipURL.path)
                else { continue }
                metas.append((serverId, meta, zipURL, file))
                totalBytes += meta.sizeBytes
            }

            let quotaBytes = Int64(quotaMB) * 1024 * 1024
            if totalBytes <= quotaBytes { return }

            // Sort by lastAccessed (oldest first)
            metas.sort { $0.meta.lastAccessed < $1.meta.lastAccessed }

            var bytesToFree = totalBytes - quotaBytes
            for entry in metas {
                if bytesToFree <= 0 { break }
                do {
                    try self.fileManager.removeItem(at: entry.zipURL)
                    try self.fileManager.removeItem(at: entry.metaURL)
                    bytesToFree -= entry.meta.sizeBytes
                } catch {
                    // Ignore errors
                }
            }
        }
    }

    // MARK: - Utility

    /// Returns the current total size of all cached archives (in bytes).
    func totalCacheSizeBytes() -> Int64 {
        guard let dir = archivesDirectory else { return 0 }
        let files =
            (try? fileManager.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [])) ?? []
        var total: Int64 = 0
        for file in files where file.pathExtension == "zip" {
            if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
                let size = attrs[.size] as? Int64
            {
                total += size
            }
        }
        return total
    }
}
