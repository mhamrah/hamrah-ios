import Foundation
import SwiftData

@Model
final class DevicePrefs {
    // Singleton pattern: only one instance should exist in the store.
    // Use a fixed UUID or a static fetch for singleton access.
    @Attribute(.unique) var id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var pushEnabled: Bool = false
    var lastPushToken: String?
    var preferredModels: [String] = []
    var archiveCacheQuotaMB: Int = 512
    var lastUpdatedAt: Date = Date()

    init(
        pushEnabled: Bool = false,
        lastPushToken: String? = nil,
        preferredModels: [String] = [],
        archiveCacheQuotaMB: Int = 512,
        lastUpdatedAt: Date = Date()
    ) {
        self.pushEnabled = pushEnabled
        self.lastPushToken = lastPushToken
        self.preferredModels = preferredModels
        self.archiveCacheQuotaMB = archiveCacheQuotaMB
        self.lastUpdatedAt = lastUpdatedAt
    }
}
