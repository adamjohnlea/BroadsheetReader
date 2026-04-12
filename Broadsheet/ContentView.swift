import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var selectedItem: FeedItem?
    @State private var searchQuery = ""
    @State private var isImportingOPML = false
    @State private var isExportingOPML = false
    @State private var exportDocument: OPMLDocument?

    @Environment(\.modelContext) private var modelContext
    @Query private var allFeeds: [Feed]
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 30

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            ItemGridView(selection: sidebarSelection, selectedItem: $selectedItem, searchQuery: searchQuery)
                .navigationSplitViewColumnWidth(min: 300, ideal: 440)
                .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search articles…")
                .onChange(of: searchQuery) { _, query in
                    if !query.isEmpty { sidebarSelection = .search }
                }
        } detail: {
            ArticleDetailView(item: selectedItem)
        }
        // Expose actions to menu bar commands
        .focusedValue(\.navigateAction,   { item in sidebarSelection = item })
        .focusedValue(\.importOPMLAction, { isImportingOPML = true })
        .focusedValue(\.exportOPMLAction, { triggerExport() })
        // On-launch refresh
        .task {
            guard !allFeeds.isEmpty else { return }
            await FeedFetcher.shared.refreshAll(feeds: allFeeds, context: modelContext)
        }
        // Background refresh (restarts when interval changes)
        .task(id: refreshInterval) {
            guard refreshInterval > 0 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double(refreshInterval) * 60))
                guard !Task.isCancelled, !allFeeds.isEmpty else { continue }
                await FeedFetcher.shared.refreshAll(feeds: allFeeds, context: modelContext)
            }
        }
        // OPML import
        .fileImporter(
            isPresented: $isImportingOPML,
            allowedContentTypes: [.xml],
            allowsMultipleSelection: false
        ) { result in
            Task { await handleImport(result: result) }
        }
        // OPML export
        .fileExporter(
            isPresented: $isExportingOPML,
            document: exportDocument,
            contentType: .xml,
            defaultFilename: "Broadsheet Feeds.opml"
        ) { _ in }
    }

    // MARK: - OPML

    private func triggerExport() {
        let ungrouped = allFeeds.filter { $0.group == nil }
        exportDocument = OPMLDocument(content: OPMLHandler.export(feedGroups: feedGroups,
                                                                   ungroupedFeeds: ungrouped))
        isExportingOPML = true
    }

    @MainActor
    private func handleImport(result: Result<[URL], Error>) async {
        guard case .success(let urls) = result,
              let url = urls.first,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let imported = OPMLHandler.parse(content)
        var groupCache: [String: FeedGroup] = [:]

        // Create missing groups first
        for feed in imported {
            guard let name = feed.groupName, groupCache[name] == nil else { continue }
            if let existing = feedGroups.first(where: { $0.name == name }) {
                groupCache[name] = existing
            } else {
                let group = FeedGroup(name: name, sortOrder: feedGroups.count + groupCache.count)
                modelContext.insert(group)
                groupCache[name] = group
            }
        }

        // Add feeds, skipping duplicates
        let existingURLs = Set(allFeeds.map(\.url))
        for item in imported where !existingURLs.contains(item.url) {
            let group = item.groupName.flatMap { groupCache[$0] }
            try? await FeedFetcher.shared.addFeed(urlString: item.url, group: group, context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FeedGroup.self, Feed.self, FeedItem.self, Bookmark.self], inMemory: true)
}
