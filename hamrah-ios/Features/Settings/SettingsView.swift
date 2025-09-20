import SwiftData
import SwiftUI
#if os(macOS)
    import AppKit
#endif

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    // Backing store (SwiftData) for a single DevicePrefs instance
    @Query private var prefsQuery: [DevicePrefs]

    // UI State
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    // Editable preferences
    @State private var pushEnabled = false
    @State private var lastPushToken: String? = nil
    @State private var preferredModels: Set<String> = []
    @State private var archiveCacheQuotaMB: Int = 512

    // Model catalog
    @State private var availableModels: [String] = defaultSuggestedModels
    @State private var isFetchingModels = false

    private static let defaultSuggestedModels: [String] = [
        "gpt-4o-mini",
        "claude-3.5-sonnet",
        "gpt-4o",
        "mistral-nemo",
        "gpt-4o-realtime-preview",
    ]

    var body: some View {
        Form {
            serverSyncSection
            notificationsSection
            modelsSection
            archiveCacheSection
            syncEngineSection
            advancedSection
        }
        .navigationTitle("Settings")
        .task {
            seedLocalFromStore()
            await fetchModelCatalog()
            await loadFromServerIfEmpty()
        }
        .alert(
            "Error", isPresented: .constant(errorMessage != nil),
            actions: {
                Button("OK") { errorMessage = nil }
            },
            message: {
                Text(errorMessage ?? "")
            })
    }

    // MARK: - View Components

    @ViewBuilder
    private var serverSyncSection: some View {
        Section("Server Sync") {
            HStack {
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Button("Load From Server") { Task { await loadFromServer() } }
                    .disabled(isLoading || accessToken() == nil)
                Button("Save To Server") { Task { await saveToServer() } }
                    .disabled(isSaving || accessToken() == nil)
            }
            .buttonStyle(.bordered)

            if let info = infoMessage {
                Text(info).font(.footnote).foregroundStyle(.secondary)
            }

            if accessToken() == nil {
                Text("Sign in to sync preferences with your account.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: $pushEnabled) {
                Label("Enable Push Notifications", systemImage: "bell.badge")
            }
            .onChange(of: pushEnabled) { _, _ in debounceAutosave() }

            HStack {
                Label("Last Registered Token", systemImage: "checkmark.seal")
                Spacer()
                Text(
                    lastPushToken.flatMap({ $0.isEmpty ? nil : "•••" + $0.suffix(6) }) ?? "None"
                )
                .foregroundStyle(.secondary)
                .font(.callout)
            }

            Button("Register For Push (OS Settings)") {
                openSystemNotificationsSettings()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var modelsSection: some View {
        Section("Models") {
            if isFetchingModels {
                HStack {
                    ProgressView()
                    Text("Fetching available models…")
                }
            } else {
                if availableModels.isEmpty {
                    Text("No models available from server. Using local defaults.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text("Models: \(availableModels.count) available")
            }

            HStack {
                Button("Refresh Model List") { Task { await fetchModelCatalog() } }
                Spacer()
                Button("Clear Selection") {
                    preferredModels = []
                    debounceAutosave()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var archiveCacheSection: some View {
        Section("Archive Cache") {
            Stepper(
                value: $archiveCacheQuotaMB,
                in: 128...4096,
                step: 64
            ) {
                HStack {
                    Label("Cache Quota", systemImage: "externaldrive")
                    Spacer()
                    Text("\(archiveCacheQuotaMB) MB")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: archiveCacheQuotaMB) { _, _ in debounceAutosave() }

            Button("Enforce Cache Quota Now") {
                ArchiveCacheManager.shared.enforceQuota(quotaMB: archiveCacheQuotaMB)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var syncEngineSection: some View {
        Section("Sync Engine") {
            Button {
                Task { await SyncEngine()._testRunSyncNow(reason: "settings_manual_sync") }
            } label: {
                Label("Run Sync Now", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var advancedSection: some View {
        Section("Advanced") {
            NavigationLink {
                APIConfigurationView()
            } label: {
                Label("API Environment", systemImage: "globe")
            }

            Button {
                copyAPIPromptToClipboard()
            } label: {
                Label("Copy Settings API Prompt", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Local Store Helpers

    private func seedLocalFromStore() {
        let prefs = fetchOrCreatePrefs()
        pushEnabled = prefs.pushEnabled
        lastPushToken = prefs.lastPushToken
        preferredModels = Set(prefs.preferredModels)
        archiveCacheQuotaMB = prefs.archiveCacheQuotaMB
    }

    private func applyToStore() {
        let prefs = fetchOrCreatePrefs()
        prefs.pushEnabled = pushEnabled
        prefs.lastPushToken = lastPushToken
        prefs.preferredModels = Array(preferredModels)
        prefs.archiveCacheQuotaMB = archiveCacheQuotaMB
        prefs.lastUpdatedAt = Date()

        do { try modelContext.save() } catch {
            errorMessage = "Failed to save preferences locally: \(error.localizedDescription)"
        }
    }

    private func fetchOrCreatePrefs() -> DevicePrefs {
        if let existing = prefsQuery.first {
            return existing
        }
        let created = DevicePrefs(
            pushEnabled: pushEnabled,
            lastPushToken: lastPushToken,
            preferredModels: Array(preferredModels),
            archiveCacheQuotaMB: archiveCacheQuotaMB
        )
        modelContext.insert(created)
        return created
    }

    // MARK: - Server Sync

    private func loadFromServerIfEmpty() async {
        // Load once from server if we have no server values yet
        if preferredModels.isEmpty || accessToken() == nil { return }
        await loadFromServer()
    }

    private func loadFromServer() async {
        guard let token = accessToken() else {
            infoMessage = "Not signed in."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let dto: DevicePrefsDTO = try await SecureAPIService.shared.get(
                endpoint: "/api/v1/device-prefs",
                accessToken: token,
                responseType: DevicePrefsDTO.self
            )
            await MainActor.run {
                mapDTOToState(dto)
                applyToStore()
                infoMessage =
                    "Loaded from server at \(Date().formatted(date: .omitted, time: .shortened))."
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load from server: \(error.localizedDescription)"
            }
        }
    }

    private func saveToServer() async {
        guard let token = accessToken() else {
            infoMessage = "Not signed in."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let dto = makeDTOFromState()
            let _: DevicePrefsDTO = try await SecureAPIService.shared.post(
                endpoint: "/api/v1/device-prefs",
                body: dto.asJSON(),
                accessToken: token,
                responseType: DevicePrefsDTO.self
            )
            await MainActor.run {
                applyToStore()
                infoMessage =
                    "Saved to server at \(Date().formatted(date: .omitted, time: .shortened))."
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save to server: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Models Catalog

    private func fetchModelCatalog() async {
        isFetchingModels = true
        defer { isFetchingModels = false }
        // Try a best-effort fetch. If missing, keep local defaults.
        do {
            struct CatalogResponse: Codable { let models: [String] }
            let token = accessToken()
            let resp: CatalogResponse = try await SecureAPIService.shared.get(
                endpoint: "/api/v1/models",
                accessToken: token,
                responseType: CatalogResponse.self
            )
            await MainActor.run {
                if !resp.models.isEmpty {
                    availableModels = resp.models
                }
            }
        } catch {
            // Non-fatal: keep defaults
        }
    }

    private func toggleModelSelection(_ model: String) {
        if preferredModels.contains(model) {
            preferredModels.remove(model)
        } else {
            preferredModels.insert(model)
        }
        debounceAutosave()
    }

    // MARK: - Utilities

    private func openSystemNotificationsSettings() {
        PlatformBridge.openAppSettings()
    }

    private func copyAPIPromptToClipboard() {
        let text = SettingsAPIPrompt.prompt
        PlatformBridge.copyToClipboard(text)
        infoMessage = "API prompt copied to clipboard."
    }

    private func debounceAutosave() {
        // Fire a delayed save to avoid spamming the server for every small change
        // Only when signed in; otherwise just persist locally.
        applyToStore()
    }

    private func accessToken() -> String? {
        KeychainManager.shared.retrieveString(for: "hamrah_access_token")
    }

    private func mapDTOToState(_ dto: DevicePrefsDTO) {
        pushEnabled = dto.push_enabled
        lastPushToken = dto.push_token
        preferredModels = Set(dto.preferred_models)
        archiveCacheQuotaMB = dto.archive_cache_quota_mb
    }

    private func makeDTOFromState() -> DevicePrefsDTO {
        DevicePrefsDTO(
            push_enabled: pushEnabled,
            push_token: lastPushToken,
            preferred_models: Array(preferredModels),
            archive_cache_quota_mb: archiveCacheQuotaMB
        )
    }
}

// MARK: - DTOs and helpers

struct DevicePrefsDTO: Codable {
    var push_enabled: Bool
    var push_token: String?
    var preferred_models: [String]
    var archive_cache_quota_mb: Int
    var last_updated_at: Date?

    init(
        push_enabled: Bool,
        push_token: String? = nil,
        preferred_models: [String],
        archive_cache_quota_mb: Int,
        last_updated_at: Date? = nil
    ) {
        self.push_enabled = push_enabled
        self.push_token = push_token
        self.preferred_models = preferred_models
        self.archive_cache_quota_mb = archive_cache_quota_mb
        self.last_updated_at = last_updated_at
    }

    func asJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "push_enabled": push_enabled,
            "preferred_models": preferred_models,
            "archive_cache_quota_mb": archive_cache_quota_mb,
        ]
        if let push_token { dict["push_token"] = push_token }
        return dict
    }
}

// MARK: - API Prompt (copy-to-clipboard)

enum SettingsAPIPrompt {
    static let prompt: String = """
        Backend API design for device-level settings synced with iOS client.

        Endpoints:
        - GET /api/v1/device-prefs
          Returns JSON:
          {
            "push_enabled": bool,
            "push_token": string | null,
            "preferred_models": string[],
            "archive_cache_quota_mb": number,
            "last_updated_at": RFC3339 string
          }

        - POST /api/v1/device-prefs
          Accepts JSON:
          {
            "push_enabled": bool,
            "push_token": string | null,
            "preferred_models": string[],
            "archive_cache_quota_mb": number
          }
          Responds with same shape as GET.

        - GET /api/v1/models
          Returns the available content model identifiers:
          { "models": string[] }

        Auth:
        - Bearer access token required.
        - Include App Attestation headers from the iOS client; treat simulator or macOS stubs with reduced trust.

        Semantics:
        - DevicePrefs is scoped to the authenticated user + device (server may identify device via device identifier or APNs token). If multi-device merge is desired, reconcile by updated_at, and compute a user-level "effective" prefs if needed.
        - archive_cache_quota_mb is advisory; the device enforces it locally via LRU eviction.
        - preferred_models influences summarization/ranking requests submitted by the client.

        Validation:
        - preferred_models must be subset of /api/v1/models if that endpoint exists; otherwise, free-form strings are accepted.
        - archive_cache_quota_mb: clamp to [128, 4096] MB.
        - push_token: optional, opaque string; store last seen token per user+device.

        Notes:
        - Avoid storing sensitive data in UserDefaults; client persists to Keychain/SwiftData as needed.
        - Server may emit push notifications to refresh link deltas when content is processed.
        """
}

// MARK: - Preview

#if DEBUG
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationStack {
                SettingsView()
                    .modelContainer(previewContainer)
            }
        }

        static var previewContainer: ModelContainer = {
            let schema = Schema([
                LinkEntity.self, ArchiveAsset.self, TagEntity.self, SyncCursor.self,
                DevicePrefs.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: config)

            let ctx = ModelContext(container)
            let prefs = DevicePrefs(
                pushEnabled: true,
                lastPushToken: "apns_dev_ABC123",
                preferredModels: ["gpt-4o-mini", "claude-3.5-sonnet"],
                archiveCacheQuotaMB: 512
            )
            ctx.insert(prefs)
            try? ctx.save()

            return container
        }()
    }
#endif
