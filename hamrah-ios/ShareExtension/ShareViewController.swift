import LinkPresentation
import Security
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

#if os(iOS)
import UIKit

/// SwiftUI-based Share Extension main view controller
class ShareViewController: UIViewController {
    private var modelContainer: ModelContainer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Initialize SwiftData container
        modelContainer = ShareExtensionDataStack.shared

        // Set up the SwiftUI hosting controller
        let hostingController = UIHostingController(rootView: ShareExtensionView())

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)

        // Handle the share input
        handleShare()
    }

    // MARK: - Share Handling

    private func handleShare() {
        guard let extensionContext = self.extensionContext else {
            presentAlertAndComplete("No extension context.")
            return
        }

        extractInput(from: extensionContext) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let input):
                self.upsertLink(input: input)
            case .failure(let error):
                self.presentAlertAndComplete(error.localizedDescription)
            }
        }
    }

    // MARK: - Persistence

    private func upsertLink(input: ExtensionInput) {
        let context = ModelContext(modelContainer)
        let now = Date()

        // Server-side canonicalization: initialize canonicalUrl with originalUrl
        let originalURL = input.url
        let canonicalURL = originalURL

        // Dedupe by originalUrl (and canonicalUrl == original as fallback)
        let existing: LinkEntity? = {
            let byOriginal = FetchDescriptor<LinkEntity>(
                predicate: #Predicate { $0.originalUrl == originalURL }
            )
            if let found = try? context.fetch(byOriginal), let first = found.first {
                return first
            }
            let byCanonical = FetchDescriptor<LinkEntity>(
                predicate: #Predicate { $0.canonicalUrl == canonicalURL }
            )
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
            // Create an empty ArchiveAsset record
            let archive = ArchiveAsset(link: link, state: "none")
            context.insert(archive)
            link.archive = archive
        }

        do {
            try context.save()
            presentCompletionUI()
        } catch {
            presentAlertAndComplete("Failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - UI

    private func presentCompletionUI() {
        // If user is not signed in yet, still save locally and offer to open the app.
        if hasAuthToken() {
            let alert = UIAlertController(
                title: "Saved", message: "Saved to Hamrah.", preferredStyle: .alert)
            alert.addAction(
                UIAlertAction(
                    title: "Done", style: .default,
                    handler: { _ in
                        self.extensionContext?.completeRequest(returningItems: [])
                    }))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(
                title: "Saved Locally",
                message: "Sign in to sync your links.",
                preferredStyle: .alert
            )
            alert.addAction(
                UIAlertAction(
                    title: "Open Hamrah", style: .default,
                    handler: { _ in
                        if let url = URL(string: "hamrah://") {
                            self.extensionContext?.open(
                                url,
                                completionHandler: { _ in
                                    self.extensionContext?.completeRequest(returningItems: [])
                                })
                        } else {
                            self.extensionContext?.completeRequest(returningItems: [])
                        }
                    }))
            alert.addAction(
                UIAlertAction(
                    title: "Done", style: .cancel,
                    handler: { _ in
                        self.extensionContext?.completeRequest(returningItems: [])
                    }))
            present(alert, animated: true)
        }
    }

    private func presentAlertAndComplete(_ message: String) {
        let alert = UIAlertController(title: "Hamrah", message: message, preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(
                title: "Done", style: .default,
                handler: { _ in
                    self.extensionContext?.cancelRequest(
                        withError: NSError(domain: "Hamrah", code: 1))
                }))
        present(alert, animated: true)
    }
}

// MARK: - SwiftUI View

struct ShareExtensionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            Text("Saving to Hamrah...")
                .font(.title2)
                .padding()
            ProgressView()
                .scaleEffect(1.2)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - ShareViewController Extensions

extension ShareViewController {
    // MARK: - Token Detection (non-blocking)

    /// Attempts to detect whether an access token exists in the shared Keychain.
    /// This does not block saving in any case.
    private func hasAuthToken() -> Bool {
        // Mirror KeychainManager's service and key
        let service = "com.hamrah.app"
        let account = "hamrah_access_token"

        // Compute shared Keychain Access Group to match the main app's KeychainManager
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
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, !data.isEmpty {
            return true
        }
        return false
    }

    // MARK: - Extraction

    private struct ExtensionInput {
        let url: URL
        let title: String?
        let sharedText: String?
        let sourceApp: String?
    }

    private func extractInput(
        from context: NSExtensionContext,
        completion: @escaping (Result<ExtensionInput, Error>) -> Void
    ) {
        guard let item = context.inputItems.first as? NSExtensionItem,
            let attachments = item.attachments, !attachments.isEmpty
        else {
            completion(
                .failure(
                    NSError(
                        domain: "Hamrah", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "No input item"])))
            return
        }

        var foundURL: URL?
        var foundText: String?
        var foundTitle: String?
        let foundSourceApp: String? = nil  // Platform APIs generally don't expose this to extensions

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
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) {
                    (item, _) in
                    defer { group.leave() }
                    if let str = item as? String { foundText = str }
                }
            }
            if provider.hasItemConformingToTypeIdentifier("com.apple.linkpresentation.metadata") {
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
                completion(
                    .failure(
                        NSError(
                            domain: "Hamrah", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No URL found"])))
                return
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
