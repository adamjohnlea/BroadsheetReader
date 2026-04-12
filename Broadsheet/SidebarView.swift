import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case today
    case allItems
    case bookmarks
    case search
    case feed(Feed)
    case feedGroup(FeedGroup)
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @Query(sort: \Feed.sortOrder) private var allFeeds: [Feed]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddFeed = false
    @State private var showingNewGroup = false
    @State private var isRefreshing = false

    private var ungroupedFeeds: [Feed] { allFeeds.filter { $0.group == nil } }
    private var allUnreadCount: Int { allFeeds.flatMap(\.items).filter { !$0.isRead }.count }

    var body: some View {
        List(selection: $selection) {
            Section {
                Label("Today", systemImage: "newspaper")
                    .tag(SidebarItem.today)
                Label("All Items", systemImage: "tray.2")
                    .badge(allUnreadCount)
                    .tag(SidebarItem.allItems)
                Label("Bookmarks", systemImage: "bookmark")
                    .tag(SidebarItem.bookmarks)
                Label("Search", systemImage: "magnifyingglass")
                    .tag(SidebarItem.search)
            }

            if !feedGroups.isEmpty || !ungroupedFeeds.isEmpty {
                Section("Feeds") {
                    ForEach(feedGroups) { group in
                        FeedGroupSection(group: group)
                    }
                    ForEach(ungroupedFeeds) { feed in
                        FeedRow(feed: feed)
                            .tag(SidebarItem.feed(feed))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Broadsheet")
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

// MARK: - New Group Sheet

private struct NewGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Group").font(.headline)
            TextField("Group name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Create") { save() }
                    .keyboardShortcut(.return)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(FeedGroup(name: trimmed, sortOrder: feedGroups.count))
        dismiss()
    }
}

// MARK: - Feed Group Section

private struct FeedGroupSection: View {
    let group: FeedGroup
    @Environment(\.modelContext) private var modelContext
    @State private var showingRename = false
    @State private var showingDelete = false
    @State private var newName = ""

    private var unreadCount: Int { group.feeds.flatMap(\.items).filter { !$0.isRead }.count }
    private var sortedFeeds: [Feed] { group.feeds.sorted { $0.sortOrder < $1.sortOrder } }

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding(get: { !group.isCollapsed },
                                set: { group.isCollapsed = !$0 })
        ) {
            ForEach(sortedFeeds) { feed in
                FeedRow(feed: feed).tag(SidebarItem.feed(feed))
            }
        } label: {
            HStack {
                Text(group.name).fontWeight(.medium)
                Spacer()
                if unreadCount > 0 {
                    Text("\(unreadCount)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .tag(SidebarItem.feedGroup(group))
        .contextMenu {
            Button("Rename…") {
                newName = group.name
                showingRename = true
            }
            Button("Mark All as Read") { group.feeds.flatMap(\.items).forEach { $0.isRead = true } }
                .disabled(unreadCount == 0)
            Divider()
            Button("Delete Group", role: .destructive) { showingDelete = true }
        }
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FeedGroup.sortOrder) private var feedGroups: [FeedGroup]
    @State private var showingDelete = false

    private var unreadCount: Int { feed.items.filter { !$0.isRead }.count }

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

            Button { feed.items.forEach { $0.isRead = true } }
                label: { Label("Mark All as Read", systemImage: "envelope.open") }
                .disabled(unreadCount == 0)

            if !feedGroups.isEmpty {
                Menu("Move to Group") {
                    Button("No Group") { feed.group = nil }
                    Divider()
                    ForEach(feedGroups) { group in
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

// MARK: - Favicon

struct FeedFavicon: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFit() }
                    else { fallbackIcon }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 16, height: 16)
    }

    private var fallbackIcon: some View {
        Image(systemName: "globe").foregroundStyle(.secondary)
    }
}
