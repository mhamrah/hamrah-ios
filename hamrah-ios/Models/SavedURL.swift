//
//  SavedURL.swift
//  hamrahIOS
//
//  SwiftData model for URLs shared with the app
//

import Foundation
import SwiftData

@Model
final class SavedURL {
    var id: UUID
    var url: String
    var title: String?
    var summary: String?
    var tags: [String]
    var processingStatus: ProcessingStatus
    var syncStatus: SyncStatus
    var createdAt: Date
    var updatedAt: Date
    var backendId: String?
    
    init(url: String) {
        self.id = UUID()
        self.url = url
        self.title = nil
        self.summary = nil
        self.tags = []
        self.processingStatus = .pending
        self.syncStatus = .local
        self.createdAt = Date()
        self.updatedAt = Date()
        self.backendId = nil
    }
    
    // Update from backend response
    func updateFromBackend(
        title: String?,
        summary: String?,
        tags: [String]?,
        processingStatus: ProcessingStatus,
        backendId: String?
    ) {
        self.title = title
        self.summary = summary
        self.tags = tags ?? []
        self.processingStatus = processingStatus
        self.backendId = backendId
        self.updatedAt = Date()
        
        // If we got data back, we're synced
        if backendId != nil {
            self.syncStatus = .synced
        }
    }
}

enum ProcessingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Ready"
        case .failed:
            return "Failed"
        }
    }
    
    var isProcessing: Bool {
        return self == .processing || self == .pending
    }
}

enum SyncStatus: String, Codable, CaseIterable {
    case local = "local"           // Only stored locally
    case syncing = "syncing"       // Being uploaded to backend
    case synced = "synced"         // Successfully synced with backend
    case syncFailed = "syncFailed" // Failed to sync with backend
    
    var displayName: String {
        switch self {
        case .local:
            return "Local Only"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Synced"
        case .syncFailed:
            return "Sync Failed"
        }
    }
    
    var needsSync: Bool {
        return self == .local || self == .syncFailed
    }
}