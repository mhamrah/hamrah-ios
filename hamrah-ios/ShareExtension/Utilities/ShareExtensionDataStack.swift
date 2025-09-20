import Foundation
import SwiftData

/// Provides a SwiftData ModelContainer for the Share Extension that stores data
/// in the shared App Group container so the main app and extension can access
/// the same database.
final class ShareExtensionDataStack {

    /// App Group identifier shared by the main app and the share extension.
    static let appGroupId = "group.app.hamrah.ios"

    /// A shared ModelContainer configured to store models in the App Group.
    /// This allows the share extension to write queued links while offline and
    /// the main app to read/sync them when available.
    static let shared: ModelContainer = {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false, groupContainer: .identifier(appGroupId))
            return try ModelContainer(
                for: LinkEntity.self,
                ArchiveAsset.self,
                TagEntity.self,
                SyncCursor.self,
                DevicePrefs.self,
                configurations: config
            )
        } catch {
            fatalError(
                "Failed to initialize SwiftData ModelContainer for Share Extension: \(error)")
        }
    }()

    /// Convenience accessor for the main ModelContext.
    static var mainContext: ModelContext {
        ModelContext(shared)
    }
}
