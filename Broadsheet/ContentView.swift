import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import UserNotifications

struct ContentView: View {
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var selectedItem: FeedItem?
    @State private var searchQuery = ""
    @State private var isImportingOPML = false
    @State private var isExportingOPML = false
    @State private var exportDocument: OPMLDocument?

    @Environment(\.modelContext) private var modelContext
    @Query private var allFeeds: [Feed]
    @Query private var allItems: [FeedItem]
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]

    private var totalUnreadCount: Int {
        allItems.filter { !$0.isHidden && !$0.userDeleted && !$0.isRead }.count
    }
    @AppStorage("refreshIntervalMinutes") private var refreshInterval = 30
    @AppStorage("hasSeededFeeds") private var hasSeededFeeds = false
    @State private var showingStarterFeeds = false
    @State private var importError: String?
    @State private var showingImportError = false
    @AppStorage("hasSeenWalkthrough") private var hasSeenWalkthrough = false
    @State private var showingWalkthrough = false
    @Environment(\.openWindow) private var openWindow

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
                .onChange(of: sidebarSelection) { _, _ in
                    selectedItem = nil
                }
        } detail: {
            ArticleDetailView(item: selectedItem)
        }
        // Expose actions to menu bar commands
        .focusedValue(\.navigateAction,       { item in sidebarSelection = item })
        .focusedValue(\.importOPMLAction,   { isImportingOPML = true })
        .focusedValue(\.exportOPMLAction,   { triggerExport() })
        .focusedValue(\.showWalkthroughAction, { showingWalkthrough = true })
        .focusedValue(\.showHelpAction, { openWindow(id: "help") })
        // On-launch refresh + first-run seeding prompt
        .task {
            if !hasSeededFeeds && allFeeds.isEmpty {
                showingStarterFeeds = true
            } else if !allFeeds.isEmpty {
                await FeedFetcher.shared.refreshAll(feeds: allFeeds, context: modelContext)
            }
        }
        .sheet(isPresented: $showingStarterFeeds) {
            StarterFeedsView()
        }
        .sheet(isPresented: $showingWalkthrough) {
            WalkthroughView()
        }
        .onAppear {
            if !hasSeenWalkthrough {
                hasSeenWalkthrough = true
                showingWalkthrough = true
            }
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
        // Update dock badge whenever unread count changes.
        // Persists the count so AppDelegate can re-apply it after auth resolves.
        // Uses both NSDockTile and UNUserNotificationCenter for reliability.
        .task(id: totalUnreadCount) {
            let count = totalUnreadCount
            UserDefaults.standard.set(count, forKey: "lastUnreadCount")
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
            NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
        }
        .alert("Import Failed", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "The OPML file could not be read.")
        }
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
        guard case .success(let urls) = result, let url = urls.first else {
            if case .failure(let error) = result {
                importError = error.localizedDescription
                showingImportError = true
            }
            return
        }

        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            importError = "Could not read the file: \(error.localizedDescription)"
            showingImportError = true
            return
        }

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
            _ = try? await FeedFetcher.shared.addFeed(urlString: item.url, group: group, context: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FeedGroup.self, Feed.self, FeedItem.self, Bookmark.self, Highlight.self], inMemory: true)
}
