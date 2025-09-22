import SwiftData
import SwiftUI

#if os(macOS)
    import AppKit
#endif

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    // Backing store (SwiftData) for a single UserPrefs instance
    @Query private var prefsQuery: [UserPrefs]

    // UI State
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    // Editable preferences
    @State private var defaultModel: String = "gpt-4o-mini"
    @State private var preferredModels: Set<String> = []

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
            modelsSection
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
    private var modelsSection: some View {
        Section("AI Models") {
            // Default model picker
            Picker("Default Model", selection: $defaultModel) {
                ForEach(availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .onChange(of: defaultModel) { _, _ in debounceAutosave() }

            // Preferred models multi-selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Models (\(preferredModels.count) selected)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                    ForEach(availableModels, id: \.self) { model in
                        Button(action: {
                            if preferredModels.contains(model) {
                                preferredModels.remove(model)
                            } else {
                                preferredModels.insert(model)
                            }
                            debounceAutosave()
                        }) {
                            Text(model)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    preferredModels.contains(model)
                                        ? Color.accentColor : Color.secondary.opacity(0.2)
                                )
                                .foregroundColor(
                                    preferredModels.contains(model) ? .white : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Model management
            if isFetchingModels {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Fetching available models…")
                }
            } else {
                Text("Available: \(availableModels.count) models")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh Models") { Task { await fetchModelCatalog() } }
                Spacer()
                Button("Clear Preferred") {
                    preferredModels = []
                    debounceAutosave()
                }
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var syncEngineSection: some View {
        Section("Sync Engine") {
            Button {
                Task { await SyncEngine().runSyncNow(reason: "settings_manual_sync") }
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
        defaultModel = prefs.defaultModel
        preferredModels = Set(prefs.preferredModels)
    }

    private func applyToStore() {
        let prefs = fetchOrCreatePrefs()
        prefs.defaultModel = defaultModel
        prefs.preferredModels = Array(preferredModels)
        prefs.lastUpdatedAt = Date()

        do { try modelContext.save() } catch {
            errorMessage = "Failed to save preferences locally: \(error.localizedDescription)"
        }
    }

    private func fetchOrCreatePrefs() -> UserPrefs {
        if let existing = prefsQuery.first {
            return existing
        }
        let created = UserPrefs(
            defaultModel: defaultModel,
            preferredModels: Array(preferredModels)
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
            let dto: UserPrefsDTO = try await SecureAPIService.shared.get(
                endpoint: "/v1/user/prefs",
                accessToken: token,
                responseType: UserPrefsDTO.self
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
            let _: UserPrefsDTO = try await SecureAPIService.shared.put(
                endpoint: "/v1/user/prefs",
                body: dto.asJSON(),
                accessToken: token,
                responseType: UserPrefsDTO.self
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
                endpoint: "/v1/models",
                accessToken: token,
                responseType: CatalogResponse.self
            )
            await MainActor.run {
                availableModels = resp.models.isEmpty ? Self.defaultSuggestedModels : resp.models
            }
        } catch {
            // Silently fall back to defaults if the endpoint is not implemented
            await MainActor.run {
                availableModels = Self.defaultSuggestedModels
            }
        }
    }

    // MARK: - Actions

    private func copyAPIPromptToClipboard() {
        #if os(iOS)
            UIPasteboard.general.string = SettingsAPIPrompt.prompt
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(SettingsAPIPrompt.prompt, forType: .string)
        #endif
        infoMessage = "API prompt copied to clipboard."
    }

    private func accessToken() -> String? {
        KeychainManager.shared.retrieveString(for: "hamrah_access_token")
    }

    private func mapDTOToState(_ dto: UserPrefsDTO) {
        defaultModel = dto.default_model
        preferredModels = Set(dto.preferred_models)
    }

    private func makeDTOFromState() -> UserPrefsDTO {
        UserPrefsDTO(
            default_model: defaultModel,
            preferred_models: Array(preferredModels)
        )
    }

    // MARK: - Autosave

    @State private var debounceTask: Task<Void, Never>?

    private func debounceAutosave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(1))
            if !Task.isCancelled {
                await MainActor.run { applyToStore() }
            }
        }
    }
}

// MARK: - DTOs and helpers

struct UserPrefsDTO: Codable {
    var default_model: String
    var preferred_models: [String]
    var last_updated_at: Date?

    init(
        default_model: String,
        preferred_models: [String],
        last_updated_at: Date? = nil
    ) {
        self.default_model = default_model
        self.preferred_models = preferred_models
        self.last_updated_at = last_updated_at
    }

    func asJSON() -> [String: Any] {
        [
            "default_model": default_model,
            "preferred_models": preferred_models,
        ]
    }
}

// MARK: - API Prompt (copy-to-clipboard)

enum SettingsAPIPrompt {
    static let prompt: String = """
        Backend API design for Hamrah iOS client user preferences.

        Required Endpoints:
        - GET /v1/user/prefs
          Returns user preferences:
          {
            "default_model": string,
            "preferred_models": string[],
            "last_updated_at": RFC3339 string
          }

        - PUT /v1/user/prefs
          Updates user preferences:
          {
            "default_model": string,
            "preferred_models": string[]
          }
          Responds with same shape as GET.

        - GET /v1/models
          Returns the available AI model identifiers from Cloudflare AI platform:
          { "models": string[] }

        - POST /v1/links
          Create/sync new links from iOS app

        Auth:
        - Bearer access token required.
        - Include App Attestation headers from the iOS client.

        Semantics:
        - User preferences are scoped to authenticated user (not device-specific).
        - default_model is the user's primary AI model choice for content processing.
        - preferred_models is an additional list of models the user wants available.
        - Model selection influences summarization/ranking requests submitted by the client.

        Validation:
        - default_model and preferred_models must be subset of /v1/models.

        Notes:
        - /v1/models endpoint should query Cloudflare AI platform for available models
        - Models are used for content processing and summarization
        """
}

// MARK: - Preview

#if DEBUG
    struct SettingsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationView {
                SettingsView()
            }
        }
    }
#endif
