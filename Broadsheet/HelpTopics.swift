import Foundation

// MARK: - Help Data Model

struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let sections: [HelpSection]

    static func == (lhs: HelpTopic, rhs: HelpTopic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct HelpSection: Identifiable {
    let id = UUID()
    let heading: String?
    let blocks: [HelpBlock]
}

struct HelpBlock: Identifiable {
    let id = UUID()
    let kind: Kind
    let text: String

    enum Kind { case paragraph, bullet, tip, shortcut }

    static func p(_ text: String) -> HelpBlock { .init(kind: .paragraph, text: text) }
    static func b(_ text: String) -> HelpBlock { .init(kind: .bullet, text: text) }
    static func tip(_ text: String) -> HelpBlock { .init(kind: .tip, text: text) }
    static func key(_ text: String) -> HelpBlock { .init(kind: .shortcut, text: text) }
}

// MARK: - All Help Topics

extension HelpTopic {
    static let allTopics: [HelpTopic] = [
        gettingStarted,
        feedsAndGroups,
        readingArticles,
        bookmarksAndNotes,
        search,
        iCloudSync,
        opml,
        keyboardShortcuts,
        settings,
    ]

    static let gettingStarted = HelpTopic(
        id: "getting-started",
        title: "Getting Started",
        subtitle: "Add your first feeds and learn the basics",
        sections: [
            HelpSection(heading: "First Launch", blocks: [
                .p("When you first open Broadsheet Reader, you'll see a walkthrough introducing the key features. You can skip it or revisit it anytime from **Help > Welcome to Broadsheet Reader**."),
                .p("After the walkthrough, you'll be offered a set of curated starter feeds. Select the ones you're interested in and they'll be added automatically."),
            ]),
            HelpSection(heading: "Adding a Feed", blocks: [
                .p("Press **⌘Shift+N** or click the **+** button in the toolbar and choose **Add Feed**. Paste in a website URL or a direct RSS/Atom feed URL — Broadsheet Reader will automatically discover the feed."),
                .tip("You don't need to find the exact RSS URL. Just paste the website address (like example.com) and Broadsheet Reader will find the feed for you."),
            ]),
            HelpSection(heading: "The Three-Column Layout", blocks: [
                .b("**Sidebar** (left) — Navigate between Today, All Items, Bookmarks, Search, and your feed groups"),
                .b("**Article List** (center) — Browse articles with unread indicators and summaries"),
                .b("**Article Detail** (right) — Read the full article content"),
            ]),
            HelpSection(heading: "Navigating", blocks: [
                .p("Click any section in the sidebar to view its articles. Use **⌘1** through **⌘3** to jump to Today, All Items, or Bookmarks. Press **⌘F** to search."),
                .p("Move between articles with **⌘↓** and **⌘↑**, or use the arrow keys when the article list has focus."),
            ]),
        ]
    )

    static let feedsAndGroups = HelpTopic(
        id: "feeds-groups",
        title: "Feeds & Groups",
        subtitle: "Organize, refresh, and manage your subscriptions",
        sections: [
            HelpSection(heading: "Adding Feeds", blocks: [
                .p("Press **⌘Shift+N** or use **File > Add Feed**. Enter a website URL or feed URL. You can optionally assign the feed to a group when adding it."),
            ]),
            HelpSection(heading: "Creating Groups", blocks: [
                .p("Use **File > New Group** to create a feed group. Groups appear as collapsible sections in the sidebar, each showing an unread count badge."),
            ]),
            HelpSection(heading: "Organizing Feeds", blocks: [
                .b("**Move to a group** — Right-click a feed and choose **Move to Group**"),
                .b("**Reorder** — Drag and drop feeds and groups in the sidebar"),
                .b("**Collapse/expand** — Click the disclosure triangle next to a group name"),
            ]),
            HelpSection(heading: "Refreshing Feeds", blocks: [
                .p("Press **⌘R** or click the refresh button to refresh all feeds. You can also right-click an individual feed and choose **Refresh**."),
                .p("Broadsheet Reader can refresh feeds automatically in the background. Configure the interval in **Settings > Auto-Refresh**."),
            ]),
            HelpSection(heading: "Feed Errors", blocks: [
                .p("If a feed fails to refresh, a warning icon appears next to it in the sidebar. Hover over the icon to see the error message."),
            ]),
            HelpSection(heading: "Deleting", blocks: [
                .p("Right-click a feed and choose **Delete Feed** to remove it and all its articles."),
                .p("Deleting a group moves its feeds to the ungrouped section — the feeds themselves are not deleted."),
            ]),
        ]
    )

    static let readingArticles = HelpTopic(
        id: "reading",
        title: "Reading Articles",
        subtitle: "Navigate, filter, and share your articles",
        sections: [
            HelpSection(heading: "Unread Indicators", blocks: [
                .p("Unread articles are marked with a green dot on the left side of the article list. Titles appear bold when unread and regular weight when read."),
                .p("By default, articles are automatically marked as read when you select them. You can change this in **Settings > Reading**."),
            ]),
            HelpSection(heading: "Filtering", blocks: [
                .p("Use the **All / Unread** toggle at the top of the article list to filter articles. This filter is remembered separately for each section."),
            ]),
            HelpSection(heading: "Marking Articles", blocks: [
                .b("**Mark as read/unread** — Click the envelope button in the toolbar, or right-click an article"),
                .b("**Mark all read** — Click **Mark All Read** in the filter bar"),
            ]),
            HelpSection(heading: "Sharing", blocks: [
                .p("Click the share button in the article toolbar to share via AirDrop, Messages, Mail, Notes, or any other sharing extension on your Mac."),
            ]),
            HelpSection(heading: "Opening in Browser", blocks: [
                .p("Click the Safari button in the article toolbar to open the full article in your default web browser."),
            ]),
            HelpSection(heading: "Deleting Articles", blocks: [
                .p("Right-click an article and choose **Delete Article**. Deleted articles are hidden permanently — they won't reappear even if the feed is refreshed."),
            ]),
        ]
    )

    static let bookmarksAndNotes = HelpTopic(
        id: "bookmarks",
        title: "Bookmarks & Notes",
        subtitle: "Save articles and add your own annotations",
        sections: [
            HelpSection(heading: "Bookmarking", blocks: [
                .p("Click the bookmark button in the article toolbar, or right-click an article and choose **Bookmark**. Bookmarked articles show a green bookmark icon in the list."),
            ]),
            HelpSection(heading: "Adding Notes", blocks: [
                .p("When an article is bookmarked, a collapsible annotations section appears below the article header. Type your thoughts in the note field (marked with a pencil icon) — notes save automatically as you type."),
            ]),
            HelpSection(heading: "Highlighting Text", blocks: [
                .p("Select text in any article and click the **Highlight** button that appears. The passage is saved as a highlight (marked with a highlighter icon) in the annotations section. Each highlight can have its own note."),
                .p("Highlighting an article automatically bookmarks it if it isn't already. Highlights are restored when you revisit the article."),
                .tip("Highlighted text and highlight notes are included in search results, so you can find saved passages later."),
            ]),
            HelpSection(heading: "Viewing Bookmarks", blocks: [
                .p("Click **Bookmarks** in the sidebar or press **⌘3** to see all your bookmarked articles. The bookmarks view always shows all bookmarks regardless of the read/unread filter."),
            ]),
            HelpSection(heading: nil, blocks: [
                .tip("Bookmarked articles are never automatically deleted by the retention policy. Even if you set retention to 7 days, your bookmarks are preserved indefinitely."),
            ]),
            HelpSection(heading: "Removing a Bookmark", blocks: [
                .p("Click the bookmark button again, or right-click and choose **Remove Bookmark**. The article and any associated note will be unbookmarked."),
            ]),
        ]
    )

    static let search = HelpTopic(
        id: "search",
        title: "Search",
        subtitle: "Find articles across all your feeds",
        sections: [
            HelpSection(heading: "How to Search", blocks: [
                .p("Click **Search** in the sidebar or press **⌘F**. Type your query in the search bar. Results appear instantly as you type."),
            ]),
            HelpSection(heading: "What's Searched", blocks: [
                .b("Article titles"),
                .b("Article summaries"),
                .b("Full article content"),
                .b("Feed names"),
                .b("Highlighted text and highlight notes"),
                .p("Search is case-insensitive — searching for \"apple\" will match \"Apple\", \"APPLE\", etc."),
            ]),
            HelpSection(heading: "Search Scope", blocks: [
                .p("Search looks through all visible articles, respecting your current retention settings. Bookmarked articles are always included regardless of age."),
            ]),
        ]
    )

    static let iCloudSync = HelpTopic(
        id: "sync",
        title: "iCloud Sync",
        subtitle: "Keep your feeds in sync across devices",
        sections: [
            HelpSection(heading: "What Syncs", blocks: [
                .b("Feeds and feed groups"),
                .b("Articles and their read/unread state"),
                .b("Bookmarks, notes, and highlights"),
                .b("Group collapse state and sort order"),
            ]),
            HelpSection(heading: "Checking Sync Status", blocks: [
                .p("Open **Settings** (⌘,) and look at the **iCloud Sync** section. A checkmark indicates sync is active."),
            ]),
            HelpSection(heading: "Troubleshooting", blocks: [
                .b("Make sure you're signed into iCloud in **System Settings > Apple Account**"),
                .b("Check that iCloud Drive is enabled"),
                .b("Ensure Broadsheet Reader has permission to use iCloud"),
            ]),
            HelpSection(heading: nil, blocks: [
                .tip("CloudKit sync is not instant — changes typically propagate within a few minutes. If iCloud is unavailable, the app falls back to local-only storage automatically. Your data is safe."),
            ]),
        ]
    )

    static let opml = HelpTopic(
        id: "opml",
        title: "OPML Import & Export",
        subtitle: "Migrate feeds from or to another reader",
        sections: [
            HelpSection(heading: "What is OPML?", blocks: [
                .p("OPML is a standard file format used by RSS readers to share feed lists. If you're switching from another reader (like Feedly, NetNewsWire, or Reeder), you can export your feeds as OPML and import them here."),
            ]),
            HelpSection(heading: "Importing Feeds", blocks: [
                .b("In your previous reader, export your feeds as an OPML file"),
                .b("In Broadsheet Reader, go to **File > Import Feeds from OPML**"),
                .b("Select the OPML file"),
                .b("Groups will be created automatically and duplicate feeds are skipped"),
                .tip("It's safe to import the same file twice — duplicates are automatically skipped."),
            ]),
            HelpSection(heading: "Exporting Feeds", blocks: [
                .b("Go to **File > Export Feeds as OPML**"),
                .b("Choose where to save the file"),
                .p("The export preserves your full group structure."),
            ]),
        ]
    )

    static let keyboardShortcuts = HelpTopic(
        id: "shortcuts",
        title: "Keyboard Shortcuts",
        subtitle: "Quick reference for all shortcuts",
        sections: [
            HelpSection(heading: "Navigation", blocks: [
                .key("⌘1 — Go to Today"),
                .key("⌘2 — Go to All Items"),
                .key("⌘3 — Go to Bookmarks"),
                .key("⌘4 — Go to Highlights"),
                .key("⌘F — Search"),
                .key("⌘↓ — Next article"),
                .key("⌘↑ — Previous article"),
            ]),
            HelpSection(heading: "Feeds", blocks: [
                .key("⌘Shift+N — Add Feed"),
                .key("⌘R — Refresh All Feeds"),
            ]),
            HelpSection(heading: "App", blocks: [
                .key("⌘, — Settings"),
                .key("⌘? — Help"),
            ]),
        ]
    )

    static let settings = HelpTopic(
        id: "settings",
        title: "Settings",
        subtitle: "Refresh intervals, retention, and preferences",
        sections: [
            HelpSection(heading: "Mark as Read on Open", blocks: [
                .p("When enabled (the default), selecting an article automatically marks it as read. Turn this off if you prefer to mark articles read manually."),
            ]),
            HelpSection(heading: "Auto-Refresh", blocks: [
                .b("**Manual only** — feeds are only refreshed when you press ⌘R"),
                .b("**Every 15 minutes**"),
                .b("**Every 30 minutes** (default)"),
                .b("**Every 60 minutes**"),
                .p("The app also refreshes all feeds once when it launches."),
            ]),
            HelpSection(heading: "Article Retention", blocks: [
                .b("**7 days** — only the last week of articles"),
                .b("**30 days** (default) — the last month"),
                .b("**90 days** — the last three months"),
                .b("**Forever** — never hide old articles"),
                .tip("Retention only affects visibility — articles aren't permanently deleted. Bookmarked articles are always visible regardless of this setting."),
            ]),
            HelpSection(heading: "iCloud Sync", blocks: [
                .p("Shows whether iCloud sync is currently active. This is read-only — sync is enabled automatically when iCloud is available."),
            ]),
        ]
    )
}
