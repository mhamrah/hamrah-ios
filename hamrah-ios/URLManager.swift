//
//  URLManager.swift
//  hamrahIOS
//
//  Manages URL saving, syncing, and processing with offline-first approach
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class URLManager: ObservableObject {
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let secureAPI = SecureAPIService.shared
    private var modelContext: ModelContext?
    private weak var authManager: NativeAuthManager?
    
    // Initialize with model context and auth manager
    func setModelContext(_ context: ModelContext, authManager: NativeAuthManager? = nil) {
        self.modelContext = context
        self.authManager = authManager
        
        // Start sync process if user is authenticated
        Task {
            await syncPendingURLs()
        }
    }
    
    // Save a new URL (offline-first)
    func saveURL(_ urlString: String) {
        guard let context = modelContext else {
            print("❌ No model context available")
            return
        }
        
        // Validate URL
        guard URL(string: urlString) != nil else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        // Check if URL already exists
        let fetchDescriptor = FetchDescriptor<SavedURL>(
            predicate: #Predicate { $0.url == urlString }
        )
        
        do {
            let existingURLs = try context.fetch(fetchDescriptor)
            if !existingURLs.isEmpty {
                print("ℹ️ URL already saved: \(urlString)")
                return
            }
        } catch {
            print("❌ Error checking for existing URL: \(error)")
        }
        
        // Create new SavedURL
        let savedURL = SavedURL(url: urlString)
        context.insert(savedURL)
        
        do {
            try context.save()
            print("✅ URL saved locally: \(urlString)")
            
            // Try to sync immediately if online
            Task {
                await syncURL(savedURL)
            }
        } catch {
            print("❌ Failed to save URL locally: \(error)")
        }
    }
    
    // Sync all pending URLs with the backend
    func syncPendingURLs() async {
        guard let context = modelContext else { return }
        
        // Get URLs that need syncing
        let fetchDescriptor = FetchDescriptor<SavedURL>(
            predicate: #Predicate { $0.syncStatus == SyncStatus.local || $0.syncStatus == SyncStatus.syncFailed }
        )
        
        do {
            let urlsToSync = try context.fetch(fetchDescriptor)
            
            for url in urlsToSync {
                await syncURL(url)
            }
        } catch {
            print("❌ Error fetching URLs to sync: \(error)")
        }
    }
    
    // Sync a specific URL with the backend
    private func syncURL(_ savedURL: SavedURL) async {
        guard let context = modelContext else { return }
        
        // Check if user is authenticated
        guard let authManager = authManager,
              authManager.isAuthenticated, 
              let accessToken = authManager.accessToken else {
            print("ℹ️ User not authenticated, skipping sync for: \(savedURL.url)")
            return
        }
        
        savedURL.syncStatus = .syncing
        try? context.save()
        
        do {
            // Submit URL to backend
            let response = try await secureAPI.post(
                endpoint: "/api/urls",
                body: [
                    "url": savedURL.url,
                    "client_id": savedURL.id.uuidString
                ],
                accessToken: accessToken,
                responseType: URLSubmissionResponse.self
            )
            
            if response.success {
                // Update with backend data
                savedURL.updateFromBackend(
                    title: response.title,
                    summary: response.summary,
                    tags: response.tags,
                    processingStatus: ProcessingStatus(rawValue: response.processingStatus ?? "pending") ?? .pending,
                    backendId: response.id
                )
                
                try context.save()
                print("✅ URL synced successfully: \(savedURL.url)")
            } else {
                throw URLError(.badServerResponse)
            }
            
        } catch {
            print("❌ Failed to sync URL: \(savedURL.url), error: \(error)")
            savedURL.syncStatus = .syncFailed
            
            DispatchQueue.main.async {
                self.syncError = "Failed to sync: \(error.localizedDescription)"
            }
            
            try? context.save()
        }
    }
    
    // Fetch updates for processing URLs
    func fetchProcessingUpdates() async {
        guard let context = modelContext else { return }
        
        // Check if user is authenticated
        guard let authManager = authManager,
              authManager.isAuthenticated, 
              let accessToken = authManager.accessToken else {
            return
        }
        
        // Get URLs that are still processing
        let fetchDescriptor = FetchDescriptor<SavedURL>(
            predicate: #Predicate { 
                ($0.processingStatus == ProcessingStatus.pending || $0.processingStatus == ProcessingStatus.processing) &&
                $0.backendId != nil
            }
        )
        
        do {
            let processingURLs = try context.fetch(fetchDescriptor)
            
            for url in processingURLs {
                guard let backendId = url.backendId else { continue }
                
                do {
                    let response = try await secureAPI.get(
                        endpoint: "/api/urls/\(backendId)",
                        accessToken: accessToken,
                        responseType: URLDetailResponse.self
                    )
                    
                    if response.success {
                        url.updateFromBackend(
                            title: response.title,
                            summary: response.summary,
                            tags: response.tags,
                            processingStatus: ProcessingStatus(rawValue: response.processingStatus ?? "pending") ?? .pending,
                            backendId: response.id
                        )
                        
                        try context.save()
                        print("✅ Updated processing status for URL: \(url.url)")
                    }
                } catch {
                    print("❌ Failed to fetch updates for URL: \(url.url)")
                }
            }
        } catch {
            print("❌ Error fetching processing URLs: \(error)")
        }
    }
    
    // Delete a URL
    func deleteURL(_ savedURL: SavedURL) {
        guard let context = modelContext else { return }
        
        // If it's synced to backend, try to delete there first
        if let backendId = savedURL.backendId {
            Task {
                await deleteURLFromBackend(backendId)
            }
        }
        
        // Delete locally
        context.delete(savedURL)
        
        do {
            try context.save()
            print("✅ URL deleted locally: \(savedURL.url)")
        } catch {
            print("❌ Failed to delete URL locally: \(error)")
        }
    }
    
    private func deleteURLFromBackend(_ backendId: String) async {
        guard let authManager = authManager,
              let accessToken = authManager.accessToken else { return }
        
        do {
            let _ = try await secureAPI.delete(
                endpoint: "/api/urls/\(backendId)",
                accessToken: accessToken,
                responseType: APIResponse.self
            )
            print("✅ URL deleted from backend: \(backendId)")
        } catch {
            print("❌ Failed to delete URL from backend: \(error)")
        }
    }
}

// MARK: - API Response Models

struct URLSubmissionResponse: Codable {
    let success: Bool
    let id: String?
    let title: String?
    let summary: String?
    let tags: [String]?
    let processingStatus: String?
    let error: String?
}

struct URLDetailResponse: Codable {
    let success: Bool
    let id: String?
    let url: String?
    let title: String?
    let summary: String?
    let tags: [String]?
    let processingStatus: String?
    let createdAt: String?
    let error: String?
}