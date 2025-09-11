//
//  ContentView.swift
//  hamrahIOS
//
//  Created by Mike Hamrah on 8/10/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedURL.createdAt, order: .reverse) private var savedURLs: [SavedURL]
    @EnvironmentObject var authManager: NativeAuthManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @EnvironmentObject var urlManager: URLManager
    @State private var showBiometricSetupPrompt = false

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(savedURLs) { savedURL in
                    SavedURLRow(savedURL: savedURL)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                urlManager.deleteURL(savedURL)
                            }
                        }
                }
                .onDelete(perform: deleteURLs)
                
                if savedURLs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No URLs saved yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Share URLs to Hamrah from Safari, Mail, or other apps to get started.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            #if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
                .frame(minWidth: 700, minHeight: 480)
            #endif
            .navigationTitle("Saved URLs")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(
                        destination: MyAccountView().environmentObject(authManager)
                            .environmentObject(biometricManager)
                    ) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    NavigationLink(
                        destination: MyAccountView().environmentObject(authManager)
                            .environmentObject(biometricManager)
                    ) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                }
                #endif
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await urlManager.syncPendingURLs()
                            await urlManager.fetchProcessingUpdates()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(urlManager.isSyncing)
                }
            }
            .refreshable {
                await urlManager.syncPendingURLs()
                await urlManager.fetchProcessingUpdates()
            }
        } detail: {
            if let selectedURL = savedURLs.first {
                SavedURLDetailView(savedURL: selectedURL)
            } else {
                Text("Select a URL to view details")
                    #if os(macOS)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    #endif
            }
        }
        .onAppear {
            checkBiometricSetupPrompt()
            urlManager.setModelContext(modelContext, authManager: authManager)
            
            Task {
                await urlManager.fetchProcessingUpdates()
            }
        }
        .sheet(isPresented: $showBiometricSetupPrompt) {
            BiometricSetupPromptView(
                onSetup: {
                    showBiometricSetupPrompt = false
                },
                onSkip: {
                    showBiometricSetupPrompt = false
                    // Mark that user was prompted so we don't ask again
                    UserDefaults.standard.set(true, forKey: "hamrah_biometric_setup_prompted")
                }
            )
            .environmentObject(biometricManager)
        }
    }

    private func checkBiometricSetupPrompt() {
        // Only show prompt if:
        // 1. Biometric auth is available
        // 2. User hasn't enabled it yet
        // 3. User hasn't been prompted before
        let hasBeenPrompted = UserDefaults.standard.bool(forKey: "hamrah_biometric_setup_prompted")

        if biometricManager.isAvailable && !biometricManager.isBiometricEnabled && !hasBeenPrompted
        {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showBiometricSetupPrompt = true
            }
        }
    }

    private func deleteURLs(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                urlManager.deleteURL(savedURLs[index])
            }
        }
    }
}

struct SavedURLRow: View {
    let savedURL: SavedURL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(savedURL.title ?? savedURL.url)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(savedURL.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    ProcessingStatusBadge(status: savedURL.processingStatus)
                    SyncStatusBadge(status: savedURL.syncStatus)
                }
            }
            
            if let summary = savedURL.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            if !savedURL.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(savedURL.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            Text(savedURL.createdAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct ProcessingStatusBadge: View {
    let status: ProcessingStatus
    
    var body: some View {
        HStack(spacing: 4) {
            if status.isProcessing {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                Image(systemName: statusIcon)
                    .font(.caption)
            }
            
            Text(status.displayName)
                .font(.caption)
        }
        .foregroundColor(statusColor)
    }
    
    private var statusIcon: String {
        switch status {
        case .pending, .processing:
            return "clock"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .pending, .processing:
            return .orange
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct SyncStatusBadge: View {
    let status: SyncStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption)
            
            Text(status.displayName)
                .font(.caption)
        }
        .foregroundColor(statusColor)
    }
    
    private var statusIcon: String {
        switch status {
        case .local:
            return "iphone"
        case .syncing:
            return "arrow.up.circle"
        case .synced:
            return "checkmark.icloud"
        case .syncFailed:
            return "exclamationmark.icloud"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .local:
            return .secondary
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .syncFailed:
            return .red
        }
    }
}

struct SavedURLDetailView: View {
    let savedURL: SavedURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(savedURL.title ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Link(savedURL.url, destination: URL(string: savedURL.url)!)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                HStack(spacing: 16) {
                    ProcessingStatusBadge(status: savedURL.processingStatus)
                    SyncStatusBadge(status: savedURL.syncStatus)
                }
                
                if let summary = savedURL.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Summary")
                            .font(.headline)
                        
                        Text(summary)
                            .font(.body)
                    }
                }
                
                if !savedURL.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 80), spacing: 8)
                        ], spacing: 8) {
                            ForEach(savedURL.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Created: \(savedURL.createdAt, format: .dateTime)")
                            .font(.caption)
                        
                        if savedURL.updatedAt != savedURL.createdAt {
                            Text("Updated: \(savedURL.updatedAt, format: .dateTime)")
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("URL Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [SavedURL.self], inMemory: true)
        .environmentObject(NativeAuthManager())
        .environmentObject(BiometricAuthManager())
        .environmentObject(URLManager())
}
