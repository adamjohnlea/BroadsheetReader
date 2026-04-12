import SwiftUI
import SwiftData
import AppKit

struct ItemGridView: View {
    let selection: SidebarItem?
    @Binding var selectedItem: FeedItem?
    let searchQuery: String
    @Query private var allItems: [FeedItem]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("markReadOnOpen") private var markReadOnOpen = true
    @AppStorage("showUnreadOnly") private var showUnreadOnly = false

    var body: some View {
        Group {
            if selection == .search && searchQuery.isEmpty {
                ContentUnavailableView("Search Articles", systemImage: "magnifyingglass",
                                       description: Text("Type in the search bar above to find articles."))
            } else if filteredItems.isEmpty {
                ContentUnavailableView("No Articles", systemImage: "newspaper",
                                       description: Text(emptyMessage))
            } else {
                List(selection: $selectedItem) {
                    ForEach(filteredItems) { item in
                        ArticleRow(item: item)
                            .tag(item)
                            .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                            .contextMenu {
                                Button(item.isRead ? "Mark as Unread" : "Mark as Read") {
                                    item.isRead.toggle()
                                }
                                Button(item.bookmark != nil ? "Remove Bookmark" : "Bookmark") {
                                    toggleBookmark(for: item)
                                }
                                Divider()
                                Button("Open in Browser") {
                                    if let url = URL(string: item.url) {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                Divider()
                                Button("Delete Article", role: .destructive) {
                                    item.isHidden = true
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .onChange(of: selectedItem) { _, item in
                    guard let item, markReadOnOpen, !item.isRead else { return }
                    item.isRead = true
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if selection != .bookmarks {
                ToolbarItem(placement: .automatic) {
                    Picker("Filter", selection: $showUnreadOnly) {
                        Text("All").tag(false)
                        Text("Unread").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filteredItems: [FeedItem] {
        let base: [FeedItem]

        let visible = allItems.filter { !$0.isHidden }

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            return visible
                .filter {
                    $0.title.lowercased().contains(q)
                    || ($0.summary?.lowercased().contains(q) ?? false)
                    || ($0.content?.lowercased().contains(q) ?? false)
                    || ($0.feed?.title.lowercased().contains(q) ?? false)
                }
                .sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
        }

        let unreadFilter: (FeedItem) -> Bool = { !$0.isRead }

        switch selection {
        case .today:
            let cutoff = Calendar.current.startOfDay(for: Date())
            let todayItems = visible.filter { ($0.publishedAt ?? $0.createdAt) >= cutoff }
            base = showUnreadOnly ? todayItems.filter(unreadFilter) : todayItems
        case .allItems, .none, .search:
            base = showUnreadOnly ? visible.filter(unreadFilter) : visible
        case .bookmarks:
            base = visible.filter { $0.bookmark != nil }
        case .feed(let feed):
            let feedItems = visible.filter { $0.feed?.persistentModelID == feed.persistentModelID }
            base = showUnreadOnly ? feedItems.filter(unreadFilter) : feedItems
        case .feedGroup(let group):
            let feedIDs = Set(group.feeds.map(\.persistentModelID))
            let groupItems = visible.filter { item in
                guard let f = item.feed else { return false }
                return feedIDs.contains(f.persistentModelID)
            }
            base = showUnreadOnly ? groupItems.filter(unreadFilter) : groupItems
        }
        return base.sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }
    }

    private var navigationTitle: String {
        if !searchQuery.isEmpty { return "Search Results" }
        switch selection {
        case .today:            return "Today"
        case .allItems, .none:  return "All Items"
        case .bookmarks:        return "Bookmarks"
        case .search:           return "Search"
        case .feed(let feed):   return feed.title
        case .feedGroup(let g): return g.name
        }
    }

    private var emptyMessage: String {
        switch selection {
        case .today:            return "No articles published today."
        case .allItems, .none:  return "No articles yet."
        case .bookmarks:        return "No bookmarks yet."
        case .search:           return "No results."
        case .feed, .feedGroup: return "No articles yet."
        }
    }

    private func toggleBookmark(for item: FeedItem) {
        if let existing = item.bookmark {
            item.bookmark = nil
            modelContext.delete(existing)
        } else {
            let bookmark = Bookmark(item: item)
            modelContext.insert(bookmark)
            item.bookmark = bookmark
        }
    }
}

// MARK: - Article Row

private struct ArticleRow: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Source + date
            HStack(spacing: 4) {
                FeedFavicon(urlString: item.feed?.faviconURL)
                Text(item.feed?.title ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let date = item.publishedAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // Title
            Text(item.title)
                .font(.subheadline)
                .fontWeight(item.isRead ? .regular : .semibold)
                .foregroundStyle(item.isRead ? .secondary : .primary)
                .lineLimit(2)

            // Summary
            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Bookmark note snippet
            if let note = item.bookmark?.note, !note.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 9))
                    Text(note)
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
