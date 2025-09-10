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
    @StateObject private var urlManager = URLManager()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            SavedURL.self,
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
                .environmentObject(urlManager)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("Received URL: \(url)")
        
        // Handle OAuth callback URLs (existing functionality)
        if url.scheme == "hamrah" {
            print("OAuth callback URL received")
            return
        }
        
        // Handle shared URLs from other apps
        if url.scheme == "http" || url.scheme == "https" {
            print("Shared URL received: \(url.absoluteString)")
            urlManager.saveURL(url.absoluteString)
        }
    }
}
