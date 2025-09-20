import Foundation
import SwiftData

@Model
final class TagEntity {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var confidence: Double?
    @Relationship var links: [LinkEntity] = []

    init(
        id: UUID = UUID(),
        name: String,
        confidence: Double? = nil,
        links: [LinkEntity] = []
    ) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.links = links
    }
}
