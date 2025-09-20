import SwiftData
import SwiftUI
import WebKit

#if os(iOS)
    import QuickLook
#endif

// MARK: - Inbox (List of Links)

struct InboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var searchText: String = ""
    @State private var sort: LinkSort = .recent
    @State private var showFailedOnly: Bool = false
    @State private var syncing: Bool = false

    // Dynamic fetch based on search/filter/sort
    private var fetchDescriptor: FetchDescriptor<LinkEntity> {
        var predicate: Predicate<LinkEntity>? = nil
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let term = searchText.lowercased()
            predicate = #Predicate<LinkEntity> {
                ($0.title ?? "").lowercased().contains(term)
                    || $0.originalUrl.absoluteString.lowercased().contains(term)
                    || ($0.snippet ?? "").lowercased().contains(term)
            }
        } else if showFailedOnly {
            predicate = #Predicate<LinkEntity> { $0.status == "failed" }
        }

        var sortDescriptors: [SortDescriptor<LinkEntity>]
        switch sort {
        case .recent:
            sortDescriptors = [SortDescriptor(\.updatedAt, order: .reverse)]
        case .title:
            sortDescriptors = [SortDescriptor(\.title, order: .forward)]
        case .domain:
            sortDescriptors = [SortDescriptor(\.canonicalUrl, order: .forward)]
        }

        return FetchDescriptor<LinkEntity>(predicate: predicate, sortBy: sortDescriptors)
    }

    @Query var links: [LinkEntity]

    init() {
        _links = Query(fetchDescriptor: fetchDescriptor)
    }

    var body: some View {
        NavigationStack {
            List {
                if links.isEmpty {
                    ContentUnavailableView(
                        "No links yet",
                        systemImage: "tray",
                        description: Text("Share links from any app to add them here."))
                } else {
                    ForEach(links, id: \.localId) { link in
                        NavigationLink(value: link.localId) {
                            LinkRowView(link: link)
                        }
                        .contextMenu {
                            Button {
                                openOriginal(link)
                            } label: {
                                Label("Open Original", systemImage: "safari")
                            }
                            #if os(iOS)
                                if let local = ArchiveCacheManager.shared.localArchiveZipURL(
                                    for: link)
                                {
                                    Button {
                                        ArchiveOpener.openArchive(at: local)
                                    } label: {
                                        Label("Open Archive", systemImage: "doc.zipper")
                                    }
                                }
                            #endif
                        }
                    }
                }
            }
            .refreshable { await runSync() }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sort) {
                            ForEach(LinkSort.allCases, id: \.self) { s in
                                Text(s.title).tag(s)
                            }
                        }
                        Toggle(isOn: $showFailedOnly) {
                            Label("Show Failed Only", systemImage: "exclamationmark.triangle")
                        }
                    } label: {
                        Label("Sort & Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    Button {
                        Task { await runSync() }
                    } label: {
                        if syncing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Sync", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(syncing)
                }
                #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                #endif
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search links")
            .onChange(of: searchText) { _, _ in
                _links = Query(fetchDescriptor: fetchDescriptor)
            }
            .onChange(of: sort) { _, _ in
                _links = Query(fetchDescriptor: fetchDescriptor)
            }
            .onChange(of: showFailedOnly) { _, _ in
                _links = Query(fetchDescriptor: fetchDescriptor)
            }
            .navigationDestination(for: UUID.self) { id in
                if let link = links.first(where: { $0.localId == id }) {
                    LinkDetailView(link: link)
                } else {
                    Text("Link not found")
                }
            }
        }
    }

    private func openOriginal(_ link: LinkEntity) {
        openURL(link.canonicalUrl)
    }

    private func runSync() async {
        syncing = true
        defer { syncing = false }
        await SyncEngine()._testRunSyncNow(reason: "inbox_pull_to_refresh")
        // Re-evaluate query after sync
        _links = Query(fetchDescriptor: fetchDescriptor)
    }
}

// MARK: - Row

struct LinkRowView: View {
    let link: LinkEntity

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            StatusDot(status: link.status)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 4) {
                Text(link.title?.isEmpty == false ? link.title! : link.canonicalUrl.absoluteString)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    if let host = link.canonicalUrl.host {
                        Text(host).foregroundStyle(.secondary)
                    }
                    if let last = relativeDate(link.updatedAt) {
                        Text("•").foregroundStyle(.secondary)
                        Text(last).foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                if let snippet = link.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .lineLimit(2)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if link.archive?.isReady == true {
                Image(systemName: "externaldrive.badge.checkmark")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Archive ready")
            }
        }
        .contentShape(Rectangle())
    }

    private func relativeDate(_ date: Date) -> String? {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

struct StatusDot: View {
    let status: String
    var color: Color {
        switch status {
        case "queued": return .yellow
        case "syncing": return .blue
        case "synced": return .green
        case "failed": return .red
        default: return .gray
        }
    }
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

// MARK: - Detail

struct LinkDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var showArchiveSheet = false
    @State private var showShareSheet = false
    @State private var presentArchive = false
    @State private var selection: ViewingMode = .original
    @State private var extractedArchiveIndexURL: URL?

    let link: LinkEntity

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control for Original vs Archive
            Picker("Viewing Mode", selection: $selection) {
                Text("Original").tag(ViewingMode.original)
                Text("Archive").tag(ViewingMode.archive)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            Group {
                switch selection {
                case .original:
                    WebView(url: link.canonicalUrl)
                case .archive:
                    ArchiveView(link: link, extractedIndexURL: $extractedArchiveIndexURL)
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(link.title ?? domainOrURLString(link))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    openOriginal()
                } label: {
                    Label("Open Original", systemImage: "safari")
                }
                #if os(iOS)
                    if link.archive?.isReady == true,
                        let local = ArchiveCacheManager.shared.localArchiveZipURL(for: link)
                    {
                        Menu {
                            Button {
                                ArchiveOpener.openArchive(at: local)
                            } label: {
                                Label("Open Archive", systemImage: "doc.zipper")
                            }
                            if let idx = extractedArchiveIndexURL {
                                Button {
                                    openURL(idx)
                                } label: {
                                    Label("Open Extracted Index", systemImage: "doc.text")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                #endif
            }
        }
        .onAppear {
            // Kick off background archive extraction attempt (best-effort)
            #if os(iOS)
                Task { extractedArchiveIndexURL = await ArchiveOpener.tryExtractIndex(for: link) }
            #endif
        }
    }

    private func openOriginal() {
        openURL(link.canonicalUrl)
    }

    private func domainOrURLString(_ link: LinkEntity) -> String {
        link.canonicalUrl.host ?? link.canonicalUrl.absoluteString
    }
}

enum ViewingMode: String, CaseIterable {
    case original
    case archive
}


// MARK: - WebView (Original)

#if os(iOS)
struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView(frame: .zero)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
#endif

// MARK: - ArchiveView (best-effort: open extracted HTML if available, otherwise guidance)

struct ArchiveView: View {
    let link: LinkEntity
    @Binding var extractedIndexURL: URL?

    var body: some View {
        Group {
            #if os(iOS)
                if let idx = extractedIndexURL {
                    WebView(url: idx)
                } else if link.archive?.isReady == true {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("Archive is cached locally")
                            .font(.headline)
                        Text(
                            "Tap ••• and choose Open Archive to preview the ZIP or Open Extracted Index if available."
                        )
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    placeholder
                }
            #else
                if link.archive?.isReady == true {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.checkmark")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("Archive cached")
                            .font(.headline)
                        Text("Open Original to view online. Archive preview is currently iOS-only.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    placeholder
                }
            #endif
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.trianglebadge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("No local archive yet")
                .font(.headline)
            Text("This link will cache automatically after sync. Pull to refresh in the Inbox.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Archive Opening / Extraction Helpers (iOS)

#if os(iOS)
    enum ArchiveOpener {
        /// Opens a ZIP archive via Quick Look.
        static func openArchive(at url: URL) {
            guard
                UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
                    != nil
            else { return }
            let preview = QLPreviewController()
            let ds = ZipPreviewDataSource(fileURL: url)
            preview.dataSource = ds
            // Present from top-most view controller
            if let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first
            {
                root.present(preview, animated: true)
            }
        }

        /// Attempts to extract an index.html from the ZIP to a temp directory and return its URL.
        /// NOTE: iOS lacks a native ZIP API; this implementation only handles the case where the archive
        /// already contains a single file named 'index.html' at top-level using URL resource values.
        /// For full ZIP extraction, integrate a ZIP library in a future patch.
        static func tryExtractIndex(for link: LinkEntity) async -> URL? {
            guard let zipURL = ArchiveCacheManager.shared.localArchiveZipURL(for: link) else {
                return nil
            }
            // Best-effort: if server sometimes returns a plain HTML file (not ZIP) we can detect by extension
            if zipURL.pathExtension.lowercased() == "html"
                || zipURL.lastPathComponent.lowercased().contains(".html")
            {
                return zipURL
            }
            // Heuristic fallback: if a sibling .html exists with same basename, prefer that.
            let htmlSibling = zipURL.deletingPathExtension().appendingPathExtension("html")
            if FileManager.default.fileExists(atPath: htmlSibling.path) {
                return htmlSibling
            }
            // Otherwise, no extraction support available right now.
            return nil
        }
    }

    private final class ZipPreviewDataSource: NSObject, QLPreviewControllerDataSource {
        private let fileURL: URL
        init(fileURL: URL) { self.fileURL = fileURL }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
            -> QLPreviewItem
        {
            return fileURL as NSURL
        }
    }

    extension UIWindowScene {
        fileprivate var keyWindow: UIWindow? {
            return self.windows.first(where: { $0.isKeyWindow })
        }
    }
#endif

// MARK: - Previews

#if DEBUG
    struct InboxView_Previews: PreviewProvider {
        static var previews: some View {
            InboxView()
                .modelContainer(previewContainer)
        }

        static var previewContainer: ModelContainer = {
            let schema = Schema([
                LinkEntity.self, ArchiveAsset.self, TagEntity.self, SyncCursor.self,
                DevicePrefs.self,
            ])
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: config)

            let ctx = ModelContext(container)

            // Seed a few items
            let now = Date()
            for i in 0..<5 {
                let url = URL(string: "https://example.com/articles/\(i)")!
                let link = LinkEntity(
                    originalUrl: url,
                    canonicalUrl: url,
                    title: "Example Article \(i)",
                    snippet: "Lorem ipsum dolor sit amet.",
                    sharedAt: now,
                    status: i % 4 == 0 ? "failed" : (i % 3 == 0 ? "queued" : "synced"),
                    updatedAt: now.addingTimeInterval(TimeInterval(-i * 3600)),
                    createdAt: now.addingTimeInterval(TimeInterval(-i * 7200))
                )
                ctx.insert(link)
                if link.status == "synced" {
                    let arch = ArchiveAsset(link: link, state: i % 2 == 0 ? "ready" : "none")
                    ctx.insert(arch)
                    link.archive = arch
                }
            }
            try? ctx.save()
            return container
        }()
    }
#endif
