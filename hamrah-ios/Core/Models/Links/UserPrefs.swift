import Foundation
import SwiftData

@Model
final class UserPrefs {
    // User-scoped preferences (not device-specific)
    @Attribute(.unique) var id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var defaultModel: String = "gpt-4o-mini"
    var preferredModels: [String] = []
    var lastUpdatedAt: Date = Date()

    init(
        defaultModel: String = "gpt-4o-mini",
        preferredModels: [String] = [],
        lastUpdatedAt: Date = Date()
    ) {
        self.defaultModel = defaultModel
        self.preferredModels = preferredModels
        self.lastUpdatedAt = lastUpdatedAt
    }
}