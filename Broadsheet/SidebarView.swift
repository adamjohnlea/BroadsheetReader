import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case today
    case allItems
    case bookmarks
    case search
    case feed(Feed)
    case feedGroup(FeedGroup)

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        switch (lhs, rhs) {
        case (.today, .today), (.allItems, .allItems), (.bookmarks, .bookmarks), (.search, .search):
            return true
        case (.feed(let a), .feed(let b)):
            return a.persistentModelID == b.persistentModelID
        case (.feedGroup(let a), .feedGroup(let b)):
            return a.persistentModelID == b.persistentModelID
        default:
            return false
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @Query(sort: \Feed.sortOrder) private var allFeeds: [Feed]
    @Query private var allItems: [FeedItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFeed = false
    @State private var showingNewGroup = false
    @State private var isRefreshing = false

    @AppStorage("retentionDays") private var retentionDays = 30

    private var ungroupedFeeds: [Feed] { allFeeds.filter { $0.group == nil } }

    private var visibleItems: [FeedItem] {
        RetentionFilter.visibleItems(allItems, retentionDays: retentionDays)
    }

    private var allUnreadCount: Int {
        visibleItems.filter { !$0.isRead }.count
    }
    private var todayUnreadCount: Int {
        let cutoff = Calendar.current.startOfDay(for: Date())
        return visibleItems.filter { !$0.isRead && ($0.publishedAt ?? $0.createdAt) >= cutoff }.count
    }
    private var bookmarkCount: Int {
        visibleItems.filter { $0.bookmark != nil }.count
    }

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Today", systemImage: "newspaper")
                    .badge(todayUnreadCount)
                    .tag(SidebarItem.today)
                Label("All Items", systemImage: "tray.2")
                    .badge(allUnreadCount)
                    .tag(SidebarItem.allItems)
                Label("Bookmarks", systemImage: "bookmark")
                    .badge(bookmarkCount)
                    .tag(SidebarItem.bookmarks)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
            }

            if !feedGroups.isEmpty || !ungroupedFeeds.isEmpty {
                Section("Feeds") {
                    ForEach(feedGroups) { group in
                        FeedGroupSection(group: group, allGroups: feedGroups)
                    }
                    .onMove { indices, destination in
                        var reordered = feedGroups
                        reordered.move(fromOffsets: indices, toOffset: destination)
                        for (i, group) in reordered.enumerated() { group.sortOrder = i }
                    }
                    ForEach(ungroupedFeeds) { feed in
                        FeedRow(feed: feed, allGroups: feedGroups)
                            .tag(SidebarItem.feed(feed))
                    }
                    .onMove { indices, destination in
                        var reordered = ungroupedFeeds
                        reordered.move(fromOffsets: indices, toOffset: destination)
                        for (i, feed) in reordered.enumerated() { feed.sortOrder = i }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Broadsheet Reader")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Add Feed…")   { showingAddFeed  = true }
                    Button("New Group…")  { showingNewGroup = true }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await refreshAll() }
                } label: {
                    if isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Refresh All", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isRefreshing || allFeeds.isEmpty)
                .help("Refresh All Feeds")
            }
        }
        // Expose actions to menu bar commands
        .focusedValue(\.refreshAction,  { await refreshAll() })
        .focusedValue(\.addFeedAction,  { showingAddFeed  = true })
        .focusedValue(\.newGroupAction, { showingNewGroup = true })
        .sheet(isPresented: $showingAddFeed)  { AddFeedView() }
        .sheet(isPresented: $showingNewGroup) { NewGroupView() }
    }

    private func refreshAll() async {
        isRefreshing = true
        await FeedFetcher.shared.refreshAll(feeds: allFeeds, context: modelContext)
        isRefreshing = false
    }
}

// MARK: - Feed Group Section

private struct FeedGroupSection: View {
    let group: FeedGroup
    let allGroups: [FeedGroup]
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [FeedItem]
    @State private var showingRename = false
    @State private var showingDelete = false
    @State private var newName = ""

    @AppStorage("retentionDays") private var retentionDays = 30

    private var unreadCount: Int {
        let feedIDs = Set((group.feeds ?? []).map(\.persistentModelID))
        return RetentionFilter.visibleItems(allItems, retentionDays: retentionDays)
            .filter { item in
                guard let f = item.feed else { return false }
                return feedIDs.contains(f.persistentModelID) && !item.isRead
            }.count
    }
    private var sortedFeeds: [Feed] { (group.feeds ?? []).sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(get: { !group.isCollapsed },
                                set: { group.isCollapsed = !$0 })
        ) {
            ForEach(sortedFeeds) { feed in
                FeedRow(feed: feed, allGroups: allGroups).tag(SidebarItem.feed(feed))
            }
            .onMove { indices, destination in
                var reordered = sortedFeeds
                reordered.move(fromOffsets: indices, toOffset: destination)
                for (i, feed) in reordered.enumerated() { feed.sortOrder = i }
            }
        } label: {
            HStack {
                Text(group.name).fontWeight(.medium)
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.accent.opacity(0.12), in: Capsule())
                }
            }
            // Context menu scoped to the group header only — does NOT intercept
            // right-clicks on child feed rows inside the DisclosureGroup.
            .contextMenu {
                Button("Rename…") {
                    newName = group.name
                    showingRename = true
                }
                Button("Mark All as Read") { (group.feeds ?? []).flatMap { $0.items ?? [] }.forEach { $0.isRead = true } }
                    .disabled(unreadCount == 0)
                Divider()
                Button("Delete Group", role: .destructive) { showingDelete = true }
            }
        }
        .tag(SidebarItem.feedGroup(group))
        .alert("Rename Group", isPresented: $showingRename) {
            TextField("Group name", text: $newName)
            Button("Rename") { if !newName.trimmingCharacters(in: .whitespaces).isEmpty { group.name = newName } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \"\(group.name)\"?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete Group", role: .destructive) { modelContext.delete(group) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Feeds in this group will become ungrouped.")
        }
    }
}

// MARK: - Feed Row

private struct FeedRow: View {
    let feed: Feed
    let allGroups: [FeedGroup]
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [FeedItem]
    @State private var showingDelete = false

    @AppStorage("retentionDays") private var retentionDays = 30

    private var unreadCount: Int {
        RetentionFilter.visibleItems(allItems, retentionDays: retentionDays)
            .filter { $0.feed?.persistentModelID == feed.persistentModelID && !$0.isRead }
            .count
    }

    var body: some View {
        Label {
            HStack {
                Text(feed.title)
                Spacer()
                if feed.fetchError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                        .help(feed.fetchError ?? "")
                }
            }
        } icon: {
            FeedFavicon(urlString: feed.faviconURL)
        }
        .badge(unreadCount)
        .contextMenu {
            Button { Task { await FeedFetcher.shared.refresh(feed, context: modelContext) } }
                label: { Label("Refresh", systemImage: "arrow.clockwise") }

            Button { (feed.items ?? []).forEach { $0.isRead = true } }
                label: { Label("Mark All as Read", systemImage: "envelope.open") }
                .disabled(unreadCount == 0)

            if !allGroups.isEmpty {
                Menu("Move to Group") {
                    Button("No Group") { feed.group = nil }
                    Divider()
                    ForEach(allGroups) { group in
                        Button(group.name) { feed.group = group }
                    }
                }
            }

            Divider()
            Button("Delete Feed", role: .destructive) { showingDelete = true }
        }
        .confirmationDialog("Delete \"\(feed.title)\"?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete Feed", role: .destructive) { modelContext.delete(feed) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All articles from this feed will be removed.")
        }
    }
}

