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
    @AppStorage("retentionDays") private var retentionDays = 30
    @State private var unreadFilters: [String: Bool] = {
        UserDefaults.standard.dictionary(forKey: "unreadFilters") as? [String: Bool] ?? [:]
    }()

    private var selectionKey: String {
        switch selection {
        case .today:             return "today"
        case .allItems, .none:   return "allItems"
        case .search:            return "search"
        case .bookmarks:         return "bookmarks"
        case .feed(let feed):    return "feed.\(feed.url)"
        case .feedGroup(let g):  return "group.\(g.name)"
        }
    }

    private var showUnreadOnly: Bool { unreadFilters[selectionKey] ?? false }
    private var unreadFilterBinding: Binding<Bool> {
        Binding(
            get: { unreadFilters[selectionKey] ?? false },
            set: {
                unreadFilters[selectionKey] = $0
                var dict = UserDefaults.standard.dictionary(forKey: "unreadFilters") as? [String: Bool] ?? [:]
                dict[selectionKey] = $0
                UserDefaults.standard.set(dict, forKey: "unreadFilters")
            }
        )
    }

    private var hasUnread: Bool { filteredItems.contains { !$0.isRead } }

    var body: some View {
        VStack(spacing: 0) {
            // Inline filter bar — anchored to the list column
            if selection != .search || !searchQuery.isEmpty {
                HStack(spacing: 8) {
                    if selection != .bookmarks {
                        Picker("Filter", selection: unreadFilterBinding) {
                            Text("All").tag(false)
                            Text("Unread").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    Spacer()
                    if hasUnread {
                        Button("Mark All Read") {
                            filteredItems.forEach { $0.isRead = true }
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(in: .rect)
            }

            // Content
            if selection == .search && searchQuery.isEmpty {
                ContentUnavailableView("Search Articles", systemImage: "text.magnifyingglass",
                                       description: Text("Search across headlines, summaries, and full articles."))
            } else if filteredItems.isEmpty {
                ContentUnavailableView(emptyTitle, systemImage: emptyIcon,
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
                                    item.userDeleted = true
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(navigationTitle)
        .focusedValue(\.nextArticleAction, { selectAdjacentArticle(direction: .next) })
        .focusedValue(\.previousArticleAction, { selectAdjacentArticle(direction: .previous) })
    }

    // MARK: - Keyboard Navigation

    private enum Direction { case next, previous }

    private func selectAdjacentArticle(direction: Direction) {
        let items = filteredItems
        guard !items.isEmpty else { return }
        guard let current = selectedItem,
              let index = items.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) else {
            // No selection — select first or last depending on direction
            selectedItem = direction == .next ? items.first : items.last
            return
        }
        switch direction {
        case .next:
            if index + 1 < items.count { selectedItem = items[index + 1] }
        case .previous:
            if index - 1 >= 0 { selectedItem = items[index - 1] }
        }
    }

    // MARK: - Filtering

    private var filteredItems: [FeedItem] {
        let base: [FeedItem]

        let retentionCutoff: Date? = retentionDays > 0
            ? Date().addingTimeInterval(-Double(retentionDays) * 86400)
            : nil

        let visible = allItems.filter { item in
            guard !item.isHidden && !item.userDeleted else { return false }
            guard item.bookmark == nil, let cutoff = retentionCutoff else { return true }
            return (item.publishedAt ?? item.createdAt) >= cutoff
        }

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
            let feedIDs = Set((group.feeds ?? []).map(\.persistentModelID))
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

    private var emptyTitle: String {
        switch selection {
        case .today:            return "All Caught Up"
        case .allItems, .none:  return "Nothing Here Yet"
        case .bookmarks:        return "No Bookmarks"
        case .search:           return "No Results"
        case .feed, .feedGroup: return "No Articles"
        }
    }

    private var emptyIcon: String {
        switch selection {
        case .today:            return "sun.max"
        case .allItems, .none:  return "newspaper"
        case .bookmarks:        return "bookmark"
        case .search:           return "magnifyingglass"
        case .feed, .feedGroup: return "newspaper"
        }
    }

    private var emptyMessage: String {
        switch selection {
        case .today:            return "Nothing new today. Enjoy the quiet."
        case .allItems, .none:  return "Add some feeds to start reading."
        case .bookmarks:        return "Bookmark articles to save them here."
        case .search:           return "Try a different search term."
        case .feed, .feedGroup: return "New articles will appear here after the next refresh."
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

    // Newspaper-style dateline: "13 APR 2026" for older, "2:34 PM" for today
    private static let datelineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = false
        return f
    }()

    private static func datelineFormatter(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            datelineFormatter.dateFormat = "h:mm a"
        } else if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            datelineFormatter.dateFormat = "d MMM"
        } else {
            datelineFormatter.dateFormat = "d MMM yyyy"
        }
        return datelineFormatter.string(from: date)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Unread indicator dot
            Circle()
                .fill(item.isRead ? .clear : .accent)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

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
                    Text(Self.datelineFormatter(for: date))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
            }

            // Title — serif font gives the list an editorial, newspaper feel
            Text(item.title)
                .font(.system(.subheadline, design: .serif))
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
                        .foregroundStyle(.accent)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } // VStack
        } // HStack
        .padding(.vertical, 6)
    }
}
