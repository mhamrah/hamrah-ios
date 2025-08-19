//
//  hamrahIOSApp.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
//

import SwiftUI
import SwiftData

@main
struct hamrahIOSApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
