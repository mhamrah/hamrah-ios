//
//  hamrahIOSApp.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
//

import SwiftData
import SwiftUI

// Using AppModelSchema for unified schema across targets

#if os(iOS)
    import BackgroundTasks
#endif

@main
struct hamrahIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    var sharedModelContainer: ModelContainer = {
        #if DEBUG
            AppModelSchema.makeSharedContainerWithRecovery()
        #else
            (try? AppModelSchema.makeSharedContainer()) ?? AppModelSchema.makeInMemoryContainer()
        #endif
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
                    _ = DeepLinkRouter.handle(url)
                    SyncEngine().triggerSync(reason: "open_url")
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                SyncEngine().triggerSync(reason: "app_active")
            }
        }
    }
}
