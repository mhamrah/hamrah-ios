import Foundation
import SwiftData

@Model
final class ArchiveAsset {
    // MARK: - Relationships
    // Each ArchiveAsset belongs to a single LinkEntity (cascade delete).
    // Inverse is the optional `archive` property on LinkEntity.
    @Relationship(deleteRule: .cascade)
    var link: LinkEntity

    // MARK: - Archive State
    // Allowed values: "none", "downloading", "ready", "failed"
    var state: String

    // MARK: - Metadata
    /// ETag used for cache validation against the server-provided archive.
    var etag: String?

    /// Relative path within the App Group container to the archive zip.
    var path: String?

    /// Size of the archive in bytes (if known).
    var sizeBytes: Int64?

    /// Last time the archive was checked for updates.
    var lastCheckedAt: Date?

    // MARK: - Init
    init(
        link: LinkEntity,
        state: String = "none",
        etag: String? = nil,
        path: String? = nil,
        sizeBytes: Int64? = nil,
        lastCheckedAt: Date? = nil
    ) {
        self.link = link
        self.state = state
        self.etag = etag
        self.path = path
        self.sizeBytes = sizeBytes
        self.lastCheckedAt = lastCheckedAt
    }

    // MARK: - Convenience
    var isReady: Bool { state == "ready" }
}
