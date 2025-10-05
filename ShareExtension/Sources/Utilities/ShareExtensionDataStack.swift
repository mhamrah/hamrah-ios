import Foundation
import SwiftData

/// Provides a SwiftData ModelContainer for the Share Extension that stores data
/// in the shared App Group container so the main app and extension can access
/// the same database.
final class ShareExtensionDataStack {

    /// Uses AppModelSchema for a unified schema shared with the main app.

    /// A shared ModelContainer configured to store models in the App Group.
    /// This allows the share extension to write queued links while offline and
    /// the main app to read/sync them when available.
    static let shared: ModelContainer = {
        #if DEBUG
            AppModelSchema.makeSharedContainerWithRecovery()
        #else
            (try? AppModelSchema.makeSharedContainer()) ?? AppModelSchema.makeInMemoryContainer()
        #endif
    }()

    /// Convenience accessor for the main ModelContext.
    static var mainContext: ModelContext {
        ModelContext(shared)
    }
}
