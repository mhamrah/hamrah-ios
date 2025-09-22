//
//  hamrahIOSApp.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
//

import SwiftData
import SwiftUI

#if os(iOS)
    import BackgroundTasks
#endif

@main
struct hamrahIOSApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            let config = ModelConfiguration(groupContainer: .identifier("group.app.hamrah.ios"))
            return try ModelContainer(
                for:
                    Item.self,
                LinkEntity.self,

                TagEntity.self,
                SyncCursor.self,
                UserPrefs.self,
                configurations: config
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Background sync registration - iOS only
    init() {
        #if os(iOS)
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "app.hamrah.ios.sync", using: nil
            ) {
                task in
                Task {
                    SyncEngine().triggerBackgroundSync()
                    task.setTaskCompleted(success: true)
                }
            }
            scheduleBackgroundSync()
        #endif
    }

    #if os(iOS)
        private func scheduleBackgroundSync() {
            let request = BGProcessingTaskRequest(identifier: "app.hamrah.ios.sync")
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("Failed to submit BGProcessingTask: \(error)")
            }
        }
    #endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    // Handle deep link URLs (OAuth callback)
                    print("Received URL: \(url)")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
