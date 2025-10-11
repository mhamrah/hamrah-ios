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
#if HAS_GOOGLE_SIGNIN && canImport(GoogleSignIn)
    import GoogleSignIn
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
            #if !targetEnvironment(simulator)
                BGTaskScheduler.shared.register(
                    forTaskWithIdentifier: "app.hamrah.ios.sync", using: nil
                ) {
                    task in
                    Task {
                        SyncEngine().triggerBackgroundSync()
                        task.setTaskCompleted(success: true)
                    }
                }
                print("🗓️ Scheduling background sync task on device...")
                scheduleBackgroundSync()
            #else
                print("ℹ️ Skipping BGTask registration on Simulator.")
            #endif
        #endif
    }

    #if os(iOS)
        private func scheduleBackgroundSync() {
            #if targetEnvironment(simulator)
                print("ℹ️ Skipping BGProcessingTask scheduling on Simulator.")
                return
            #endif
            print("📝 Preparing BGProcessingTask request for 'app.hamrah.ios.sync'")
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
                    #if HAS_GOOGLE_SIGNIN && canImport(GoogleSignIn)
                        print("🔎 Attempting Google Sign-In URL handling...")
                        if GIDSignIn.sharedInstance.handle(url) {
                            print("✅ Handled Google Sign-In URL")
                            return
                        } else {
                            print(
                                "↪️ Google Sign-In did not handle URL, falling back to deep link router"
                            )
                        }
                    #endif
                    let routed = DeepLinkRouter.handle(url)
                    print("🔗 DeepLinkRouter handled: \(routed)")
                    SyncEngine().triggerSync(reason: "open_url")
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                SyncEngine().triggerSync(reason: "app_active")
            }
        }
    }
}
