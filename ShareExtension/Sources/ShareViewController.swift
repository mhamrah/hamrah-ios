import LinkPresentation
import Security
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
    import UIKit
    import Social

    // MARK: - Share Extension Entry Point
    /// Uses SLComposeServiceViewController so the extension is recognized by iOS share sheet.
    class ShareViewController: SLComposeServiceViewController {
        private var modelContainer: ModelContainer!
        private var pendingInput: ExtensionInput?

        override func viewDidLoad() {
            super.viewDidLoad()
            modelContainer = ShareExtensionDataStack.shared
            // Pre-fetch the input so tapping Post is fast.
            if pendingInput == nil {
                extractInput(from: extensionContext!) { [weak self] result in
                    self?.pendingInput = try? result.get()
                }
            }
            placeholder = "Save to Hamrah"
        }

        // User can always post (we accept a single URL / text)
        override func isContentValid() -> Bool { true }

        override func didSelectPost() {
            // Ensure we have extracted input; if not, re-extract synchronously then save.
            if let input = pendingInput {
                upsertLink(input: input)
            } else {
                extractInput(from: extensionContext!) { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .success(let input):
                        self.upsertLink(input: input)
                    case .failure(let err):
                        self.cancelRequest(with: err.localizedDescription)
                    }
                }
            }
        }

        override func configurationItems() -> [Any]! { [] }

        // MARK: - Persistence
        private func upsertLink(input: ExtensionInput) {
            let context = ModelContext(modelContainer)
            let now = Date()
            let originalURL = input.url
            let canonicalURL = originalURL

            let existing: LinkEntity? = {
                let byOriginal = FetchDescriptor<LinkEntity>(
                    predicate: #Predicate { $0.originalUrl == originalURL })
                if let found = try? context.fetch(byOriginal), let first = found.first {
                    return first
                }
                let byCanonical = FetchDescriptor<LinkEntity>(
                    predicate: #Predicate { $0.canonicalUrl == canonicalURL })
                if let found = try? context.fetch(byCanonical), let first = found.first {
                    return first
                }
                return nil
            }()

            if let link = existing {
                link.saveCount += 1
                link.lastSavedAt = now
                if link.title == nil, let title = input.title { link.title = title }
                if link.snippet == nil, let txt = input.sharedText { link.snippet = txt }
                link.updatedAt = now
            } else {
                let link = LinkEntity(
                    originalUrl: originalURL,
                    canonicalUrl: canonicalURL,
                    title: input.title,
                    snippet: input.sharedText,
                    sourceApp: input.sourceApp,
                    sharedText: input.sharedText,
                    sharedAt: now,
                    status: "queued",
                    updatedAt: now,
                    createdAt: now
                )
                context.insert(link)
            }

            do {
                try context.save()
                finishSuccessfully(authAware: hasAuthToken())
            } catch {
                cancelRequest(with: "Failed to save: \(error.localizedDescription)")
            }
        }

        private func finishSuccessfully(authAware: Bool) {
            // After saving, always try to wake the main app to trigger sync via URL scheme.
            if let url = URL(string: "hamrah://sync") {
                extensionContext?.open(url) { _ in
                    self.extensionContext?.completeRequest(returningItems: nil)
                }
            } else {
                extensionContext?.completeRequest(returningItems: nil)
            }
        }

        private func cancelRequest(with message: String) {
            let err = NSError(
                domain: "HamrahShare", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
            extensionContext?.cancelRequest(withError: err)
        }
    }

    // MARK: - Helpers
    extension ShareViewController {
        private func hasAuthToken() -> Bool {
            let service = "com.hamrah.app"
            let account = "hamrah_access_token"
            let accessGroup =
                (Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String).map {
                    "\($0)app.hamrah.ios"
                }
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            if let accessGroup = accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return status == errSecSuccess && (result as? Data)?.isEmpty == false
        }

        struct ExtensionInput {
            let url: URL
            let title: String?
            let sharedText: String?
            let sourceApp: String?
        }

        fileprivate func extractInput(
            from context: NSExtensionContext,
            completion: @escaping (Result<ExtensionInput, Error>) -> Void
        ) {
            guard let item = context.inputItems.first as? NSExtensionItem,
                let attachments = item.attachments, !attachments.isEmpty
            else {
                return completion(
                    .failure(
                        NSError(
                            domain: "Hamrah", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No input item"])))
            }
            var foundURL: URL?
            var foundText: String?
            var foundTitle: String?
            let foundSourceApp: String? = nil
            let group = DispatchGroup()
            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) {
                        (item, _) in
                        defer { group.leave() }
                        if let url = item as? URL {
                            foundURL = url
                        } else if let str = item as? String, let url = URL(string: str) {
                            foundURL = url
                        }
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil)
                    { (item, _) in
                        defer { group.leave() }
                        if let str = item as? String { foundText = str }
                    }
                }
                if provider.hasItemConformingToTypeIdentifier("com.apple.linkpresentation.metadata")
                {
                    group.enter()
                    provider.loadItem(
                        forTypeIdentifier: "com.apple.linkpresentation.metadata", options: nil
                    ) { (item, _) in
                        defer { group.leave() }
                        if let meta = item as? LPLinkMetadata, let title = meta.title {
                            foundTitle = title
                        }
                    }
                }
            }
            group.notify(queue: .main) {
                guard let url = foundURL else {
                    return completion(
                        .failure(
                            NSError(
                                domain: "Hamrah", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "No URL found"])))
                }
                completion(
                    .success(
                        ExtensionInput(
                            url: url, title: foundTitle, sharedText: foundText,
                            sourceApp: foundSourceApp)))
            }
        }
    }
#endif
