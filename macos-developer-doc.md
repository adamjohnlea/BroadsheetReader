# LS-Freeder macOS — Developer Doc for Claude Code

This document tells Claude Code how to build a native macOS SwiftUI version of LS-Freeder (an RSS reader currently implemented as a PHP/SQLite web app). Hand this file to Claude Code as context when starting the macOS project.

---

## 1. Project Identity

**Name:** LS-Freeder (macOS)
**Bundle ID:** com.adamlea.ls-freeder
**Minimum deployment:** macOS 15.0 (Sequoia)
**Language:** Swift 6, strict concurrency
**UI framework:** SwiftUI (AppKit bridge only when SwiftUI cannot express a desktop behavior)
**Persistence:** SwiftData backed by SQLite (mirrors the web app's schema)
**Feed parsing:** FeedKit (Swift RSS/Atom parser)
**Design language:** Reeder 5 — minimal, thin typography, generous whitespace, favicon-based feed identity

---

## 2. Global Rules (from ~/.claude/CLAUDE.md)

These are already loaded into Claude Code's context but are restated here so they are never missed:

- **HIG compliance** — Settings scene via `Cmd+,`, menu bar commands with keyboard shortcuts, all interactive elements as `Button` (never `onTapGesture`), `.accessibilityLabel()` on all images, VoiceOver throughout, context menus on all list/grid items, keyboard navigation everywhere, native controls preferred, destructive actions require confirmation, async operations show progress, errors always surfaced.
- **Build workflow** — `make` to build, `make test` for unit tests, `make ui-test` for UI tests. All `xcodebuild` output piped through `xcbeautify`. Zero warnings.
- **Code standards** — No fallbacks without written approval. One code path per action (button, menu, shortcut, gesture all call the same method). Semantic system colors and fonts only. No backward-compat shims for new code.
- **Testing** — Run `make test` during implementation. `make ui-test` only at handoff or when asked.
- **Debugging** — Add verbose `Logger` events when stuck. Never silently swallow errors.
- **Git safety** — No destructive git commands without written approval.

---

## 3. Scene Model

The app uses **four explicit scenes** — do not collapse everything into one ContentView:

```swift
@main
struct LSFreederApp: App {
    var body: some Scene {
        // 1. Main reader window — three-column NavigationSplitView
        WindowGroup {
            MainReaderView()
        }
        .commands { AppCommands() }
        .defaultSize(width: 1100, height: 750)

        // 2. Settings (Cmd+,)
        Settings {
            SettingsView()
        }

        // 3. Article detail — opened in a new window from double-click or Cmd+Enter
        Window("Article", id: "article-detail") {
            ArticleDetailWindow()
        }

        // 4. Add Feed sheet is presented modally, not as a separate scene
    }
}
```

**No MenuBarExtra** unless explicitly requested — this is a focused reader app, not a menu-bar utility.

---

## 4. Build & Run Loop

### 4a. Makefile (project root)

Create a `Makefile` at the Xcode project root with these targets. Claude Code must use these — never run raw `xcodebuild` output without piping through `xcbeautify`.

```makefile
SCHEME = LS-Freeder
DESTINATION = platform=macOS

.PHONY: build test ui-test clean

build:
	set -o pipefail && xcodebuild build \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		2>&1 | xcbeautify

test:
	set -o pipefail && xcodebuild test \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:LS-FreederTests \
		2>&1 | xcbeautify

ui-test:
	set -o pipefail && xcodebuild test \
		-scheme "$(SCHEME)" \
		-destination "$(DESTINATION)" \
		-only-testing:LS-FreederUITests \
		2>&1 | xcbeautify

clean:
	xcodebuild clean -scheme "$(SCHEME)" -destination "$(DESTINATION)" 2>&1 | xcbeautify
```

### 4b. Validation loop

After every meaningful change, Claude Code must:

1. Run `make build` — confirm zero errors, zero warnings.
2. If tests exist for the changed layer, run `make test`.
3. Report exactly which commands were run and their outcome.

Do not claim a build passed if xcbeautify was not installed or the command was not actually run.

---

## 5. Architecture

### Layer mapping from web app to macOS

| Web Layer | macOS Equivalent | Location |
|---|---|---|
| `src/Domain/` (entities, repository protocols) | Swift value types + protocols | `Sources/Domain/` |
| `src/Application/` (Handlers) | Service classes | `Sources/Services/` |
| `src/Infrastructure/Database/` | SwiftData `ModelContainer` + repository implementations | `Sources/Persistence/` |
| `src/Infrastructure/Feed/RssParser.php` | FeedKit wrapper | `Sources/Services/FeedService.swift` |
| `src/Controller/` | SwiftUI Views + ViewModels | `Sources/Views/`, `Sources/ViewModels/` |
| `templates/` (Twig) | SwiftUI Views | `Sources/Views/` |

### Build order

Implement in this sequence, running `make build` (and `make test` when tests exist) after each layer:

1. **SwiftData models** — mirror the web DB schema exactly
2. **Repository protocols + SwiftData implementations**
3. **Service layer** — feed parsing, sync, search, OPML
4. **ViewModels** — one per major view, `@Observable`
5. **Views** — sidebar, item list, article detail, settings
6. **Menu commands & keyboard shortcuts**
7. **Background refresh & notifications**

### Folder structure

```
LS-Freeder/
├── LS-Freeder/
│   ├── App/
│   │   ├── LSFreederApp.swift          # Scene declarations
│   │   └── AppCommands.swift           # Menu bar commands
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Feed.swift
│   │   │   ├── FeedGroup.swift
│   │   │   ├── FeedItem.swift
│   │   │   ├── Bookmark.swift
│   │   │   ├── Highlight.swift
│   │   │   └── ReadStatus.swift
│   │   └── Protocols/
│   │       ├── FeedRepository.swift
│   │       ├── ItemRepository.swift
│   │       ├── BookmarkRepository.swift
│   │       └── HighlightRepository.swift
│   ├── Persistence/
│   │   ├── ModelContainer+Extension.swift
│   │   └── Repositories/
│   │       ├── SwiftDataFeedRepository.swift
│   │       ├── SwiftDataItemRepository.swift
│   │       ├── SwiftDataBookmarkRepository.swift
│   │       └── SwiftDataHighlightRepository.swift
│   ├── Services/
│   │   ├── FeedService.swift           # FeedKit parsing + refresh
│   │   ├── SyncService.swift           # Background fetch orchestration
│   │   ├── SearchService.swift         # Full-text search
│   │   ├── OPMLService.swift           # Import/export
│   │   ├── FaviconService.swift        # Fetch + cache favicons
│   │   └── HighlightService.swift
│   ├── ViewModels/
│   │   ├── SidebarViewModel.swift
│   │   ├── ItemListViewModel.swift
│   │   ├── ArticleViewModel.swift
│   │   ├── FeedManagementViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   ├── StatsViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/
│   │   ├── MainReaderView.swift        # NavigationSplitView root
│   │   ├── Sidebar/
│   │   │   ├── SidebarView.swift
│   │   │   ├── FeedGroupRow.swift
│   │   │   └── FeedRow.swift
│   │   ├── ItemList/
│   │   │   ├── ItemListView.swift
│   │   │   └── ItemRow.swift
│   │   ├── Article/
│   │   │   ├── ArticleDetailView.swift
│   │   │   ├── ArticleToolbar.swift
│   │   │   └── HighlightOverlay.swift
│   │   ├── Bookmarks/
│   │   │   └── BookmarksView.swift
│   │   ├── Search/
│   │   │   └── SearchResultsView.swift
│   │   ├── Stats/
│   │   │   ├── StatsView.swift
│   │   │   └── ContributionGrid.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   ├── Feed Management/
│   │   │   ├── AddFeedSheet.swift
│   │   │   └── ManageFeedsView.swift
│   │   └── Components/
│   │       ├── UnreadBadge.swift
│   │       ├── FaviconImage.swift
│   │       └── EmptyStateView.swift
│   └── Utilities/
│       ├── Logger+App.swift
│       ├── KeyboardShortcuts.swift
│       └── HTMLSanitizer.swift
├── LS-FreederTests/
│   ├── Domain/
│   ├── Services/
│   └── ViewModels/
├── LS-FreederUITests/
├── Makefile
└── README.md
```

---

## 6. Data Model (SwiftData)

Mirror the web app's SQLite schema. All models use `@Model` macro.

### Feed

```swift
@Model
final class Feed {
    @Attribute(.unique) var id: UUID
    var title: String
    var url: URL                    // RSS feed URL
    var siteUrl: URL?              // Homepage for favicon
    var faviconData: Data?         // Cached favicon image
    var feedDescription: String?
    var lastFetchedAt: Date?
    var fetchError: String?
    var sortOrder: Int
    var createdAt: Date

    @Relationship var group: FeedGroup?
    @Relationship(deleteRule: .cascade, inverse: \FeedItem.feed) var items: [FeedItem]
}
```

### FeedGroup

```swift
@Model
final class FeedGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var isCollapsed: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Feed.group) var feeds: [Feed]
}
```

### FeedItem

```swift
@Model
final class FeedItem {
    @Attribute(.unique) var guid: String
    var title: String
    var url: URL
    var author: String?
    var summary: String?           // 300 chars max
    var content: String?           // Full HTML
    var imageUrl: URL?
    var publishedAt: Date
    var createdAt: Date
    var isRead: Bool
    var isBookmarked: Bool

    @Relationship var feed: Feed?
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.item) var bookmark: Bookmark?
    @Relationship(deleteRule: .cascade, inverse: \Highlight.item) var highlights: [Highlight]
}
```

### Bookmark

```swift
@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var note: String?
    var createdAt: Date

    @Relationship var item: FeedItem?
}
```

### Highlight

```swift
@Model
final class Highlight {
    @Attribute(.unique) var id: UUID
    var text: String
    var note: String?
    var color: HighlightColor      // enum: yellow, green, blue, pink
    var startOffset: Int
    var endOffset: Int
    var createdAt: Date

    @Relationship var item: FeedItem?
}

enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink
}
```

**Note:** The web app is multi-user. The macOS app is single-user — no User model, no auth. All data belongs to the local user.

---

## 7. UI Specification

### 7a. Main window — Three-column NavigationSplitView

```
┌─────────────┬──────────────────┬──────────────────────────────┐
│ Sidebar     │ Item List        │ Article Detail               │
│ (220pt)     │ (320pt)          │ (flexible)                   │
│             │                  │                              │
│ Smart Views │ [Feed title bar] │ [Article title]              │
│  Today      │                  │ [Author · Date · Feed]       │
│  All Items  │ Item row         │                              │
│  Bookmarks  │ Item row         │ [Full article content]       │
│  Highlights │ Item row (read)  │                              │
│             │ Item row         │ [Highlights sidebar]         │
│ FEEDS       │                  │                              │
│ ▾ AI/Tech   │                  │                              │
│   HN   (12)│                  │                              │
│   SW    (8) │                  │                              │
│ ▾ Research  │                  │                              │
│   ArXiv (3) │                  │                              │
│             │                  │                              │
│ + Add Feed  │                  │                              │
│ ⚙ Settings  │                  │                              │
└─────────────┴──────────────────┴──────────────────────────────┘
```

- Use `NavigationSplitView(columnVisibility:)` with `.all` default.
- Sidebar minimum 180pt, ideal 220pt. Content column minimum 280pt.
- Sidebar selection drives which items appear in the middle column.
- Item list selection drives article detail in the trailing column.

### 7b. Sidebar sections

**Smart Views** (top, always visible):
- Today — items published in last 24 hours
- All Items — all unread items, with total unread count badge
- Bookmarks — all bookmarked items
- Highlights — all highlighted items
- Search — activates search field in item list
- Stats — reading analytics (contribution grid, streaks, charts)

**Feeds** (below, grouped):
- Collapsible disclosure groups per FeedGroup
- Each feed row: favicon (16pt) + title + unread count badge
- Feeds without a group shown in an "Ungrouped" section
- Context menu on each feed: Mark All Read, Refresh, Edit, Delete
- Context menu on each group: Mark All Read, Rename, Delete
- "Add Feed" button at bottom of sidebar
- Drag-and-drop reordering for feeds and groups

### 7c. Item list (middle column)

- Each row: unread indicator (green circle), title (bold if unread), feed name with favicon, relative timestamp, bookmark icon
- Sort: newest first (published_at DESC)
- Toolbar: filter toggle (All / Unread Only), Mark All Read button, Refresh button
- Context menu on each item: Mark Read/Unread, Toggle Bookmark, Open in Browser, Copy Link
- Swipe actions: leading = toggle read, trailing = toggle bookmark
- Click selects and shows in detail column. Double-click opens in separate window.
- Items older than 30 days with isRead=true can be pruned on next sync.

### 7d. Article detail (trailing column)

- Header: feed favicon + feed name, published date, author
- Title (large, `.title` font)
- Action toolbar: Open in Safari, Toggle Bookmark, Toggle Read, Share
- Article content rendered as attributed string or WKWebView (AppKit bridge if needed for full HTML fidelity)
- Text selection enables highlight popover (pick color, add note)
- Existing highlights shown inline with colored background
- Font size adjustable (Cmd+Plus/Minus or Settings)

### 7e. Settings scene (Cmd+,)

Tabs:
- **General** — default view on launch (Today/All Items), refresh interval (15/30/60 min), mark-as-read behavior, font size
- **Appearance** — follow system / light / dark, accent color
- **Feeds** — manage feeds and groups (list with edit/delete)
- **OPML** — import/export buttons
- **Keyboard Shortcuts** — reference table (read-only display)

### 7f. Keyboard shortcuts

Map these via `.keyboardShortcut()` on commands and `.onKeyPress()` in views. All must call the same code path as the equivalent button/menu action.

| Key | Action |
|---|---|
| `J` / `K` | Next / previous item in list |
| `Enter` or `O` | Open selected article in detail |
| `Cmd+Enter` | Open in separate window |
| `M` | Toggle read/unread |
| `B` | Toggle bookmark |
| `Cmd+Shift+A` | Mark all read in current view |
| `V` | Open original URL in browser |
| `Cmd+F` | Focus search |
| `Cmd+R` | Refresh current feed / all feeds |
| `Cmd+,` | Settings (built-in) |
| `Cmd+I` | Show/hide sidebar |
| `Cmd+Plus/Minus` | Increase/decrease article font size |

### 7g. Menu bar commands

```swift
struct AppCommands: Commands {
    var body: some Commands {
        // File menu
        CommandGroup(after: .newItem) {
            Button("Add Feed...") { ... }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Import OPML...") { ... }
            Button("Export OPML...") { ... }
        }

        // View menu
        CommandGroup(after: .sidebar) {
            Button("Today") { ... }.keyboardShortcut("1", modifiers: .command)
            Button("All Items") { ... }.keyboardShortcut("2", modifiers: .command)
            Button("Bookmarks") { ... }.keyboardShortcut("3", modifiers: .command)
            Button("Highlights") { ... }.keyboardShortcut("4", modifiers: .command)
            Button("Stats") { ... }.keyboardShortcut("5", modifiers: .command)
        }

        // Item menu
        CommandMenu("Item") {
            Button("Mark as Read") { ... }.keyboardShortcut("m")
            Button("Toggle Bookmark") { ... }.keyboardShortcut("b")
            Button("Open in Browser") { ... }.keyboardShortcut("v")
            Divider()
            Button("Mark All as Read") { ... }
                .keyboardShortcut("a", modifiers: [.command, .shift])
        }

        // Feed menu
        CommandMenu("Feed") {
            Button("Refresh") { ... }.keyboardShortcut("r", modifiers: .command)
            Button("Refresh All Feeds") { ... }
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
```

---

## 8. Feature Parity Checklist

These are the web app features. Implement them in priority order:

### Phase 1 — Core Reader (MVP)
- [ ] SwiftData models + ModelContainer setup
- [ ] Feed parsing with FeedKit (RSS 2.0, Atom 1.0)
- [ ] Add feed by URL (auto-discover RSS from HTML page)
- [ ] Favicon fetch and cache
- [ ] Three-column NavigationSplitView layout
- [ ] Sidebar with smart views and feed groups
- [ ] Item list with unread indicators
- [ ] Article detail with HTML content rendering
- [ ] Mark read/unread (click to read, explicit toggle)
- [ ] Unread counts in sidebar
- [ ] Background refresh on timer (configurable interval)
- [ ] Keyboard shortcuts (J/K navigation, M, B, V)
- [ ] Menu bar commands
- [ ] Settings scene (General + Appearance tabs)

### Phase 2 — Organization
- [ ] Feed groups (create, rename, delete, collapse)
- [ ] Drag-and-drop reorder for feeds and groups
- [ ] Bookmark toggle with optional notes
- [ ] Bookmarks smart view
- [ ] Context menus on all sidebar and list items
- [ ] Mark all read per feed / per group
- [ ] OPML import/export
- [ ] Feed management view (edit, delete, assign to group)

### Phase 3 — Search & Highlights
- [ ] Full-text search across titles, summaries, content
- [ ] Search results view with query highlighting
- [ ] Text selection highlighting with color picker
- [ ] Highlight notes
- [ ] Highlights smart view (grouped by article)
- [ ] Export highlights to Markdown

### Phase 4 — Analytics & Polish
- [ ] Stats view: contribution grid (52 weeks x 7 days)
- [ ] Reading streaks (current + longest)
- [ ] Daily read counts chart (Swift Charts)
- [ ] Top feeds by reads chart
- [ ] Open in separate window (Cmd+Enter)
- [ ] Article font size control
- [ ] Starter feed suggestions on first launch
- [ ] Prune old read items (30+ days)

### Phase 5 — Distribution
- [ ] App icon
- [ ] About window
- [ ] Manual Xcode archive for one-off builds
- [ ] Scripted archive + notarization for repeatable distribution
- [ ] Hardened runtime, entitlements review
- [ ] Sandbox: network access (feeds), file access (OPML import/export)

---

## 9. Feed Parsing & Sync

### Refresh strategy

```swift
// SyncService.swift
@Observable
final class SyncService {
    private var refreshTimer: Timer?
    private let feedService: FeedService
    private let modelContainer: ModelContainer

    func startAutoRefresh(interval: TimeInterval = 900) { // 15 min default
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refreshAllFeeds() }
        }
    }

    func refreshAllFeeds() async {
        // Fetch each feed in parallel with TaskGroup
        // Parse with FeedKit
        // Deduplicate by guid
        // Insert new items, update existing
        // Update feed.lastFetchedAt
        // On error: set feed.fetchError, do not remove existing items
    }

    func refreshFeed(_ feed: Feed) async {
        // Single-feed variant
    }
}
```

### Favicon handling

```swift
// FaviconService.swift
// 1. Try /favicon.ico at site root
// 2. If that fails, fetch HTML and parse <link rel="icon"> or <link rel="shortcut icon">
// 3. Download and store as Data on Feed model
// 4. Re-discover on manual refresh if current URL returns 404
```

---

## 10. Search

For Phase 3, use SwiftData `#Predicate` with string matching for basic search. If performance is inadequate on large datasets, consider:

- **SearchKit** (macOS framework) for ranked full-text search
- **SQLite FTS5** directly via a custom SwiftData store or GRDB

The web app uses SQLite FTS5 with triggers. Matching that fidelity may require dropping down to raw SQLite for the search index while keeping SwiftData for everything else.

---

## 11. HTML Content Rendering

Article content is full HTML. Options in priority order:

1. **AttributedString from HTML** — lightweight, native, but limited CSS support. Good enough for simple articles.
2. **WKWebView via NSViewRepresentable** — full HTML/CSS fidelity, handles images, embedded media. Requires AppKit bridge. This is the likely choice for a faithful reader experience.

If using WKWebView, inject a custom stylesheet that matches the app's typography and color scheme (light/dark). Disable JavaScript and external navigation — open links in Safari via `WKNavigationDelegate`.

---

## 12. AppKit Bridges (narrow, only when needed)

Only use these when SwiftUI has no equivalent:

| Need | Bridge |
|---|---|
| Full HTML article rendering | `WKWebView` via `NSViewRepresentable` |
| OPML file open/save dialogs | `NSOpenPanel` / `NSSavePanel` |
| First-responder control (search field focus) | `NSViewRepresentable` wrapper if `.focused()` is insufficient |
| Drag-and-drop from Finder (OPML import) | `onDrop` modifier with `UTType` |

Do **not** bridge: toolbar, sidebar, context menus, keyboard shortcuts, Settings scene, split views — all of these have native SwiftUI equivalents.

---

## 13. Logging

Use structured logging for runtime debugging:

```swift
import os

extension Logger {
    static let feedSync = Logger(subsystem: "com.adamlea.ls-freeder", category: "FeedSync")
    static let ui = Logger(subsystem: "com.adamlea.ls-freeder", category: "UI")
    static let persistence = Logger(subsystem: "com.adamlea.ls-freeder", category: "Persistence")
}

// Usage
Logger.feedSync.info("Refreshing feed: \(feed.title)")
Logger.feedSync.error("Failed to parse feed: \(error.localizedDescription)")
```

Verify with: `log stream --predicate 'subsystem == "com.adamlea.ls-freeder"'`

---

## 14. Design Tokens

Use semantic system colors and fonts. Do not hard-code any colors.

| Element | Value |
|---|---|
| Background | `.background` (system) |
| Sidebar background | `.windowBackgroundColor` via system |
| Card/row hover | `.secondary` with low opacity |
| Primary text | `.primary` |
| Secondary text | `.secondary` |
| Muted text | `.tertiary` |
| Accent / unread dot | `.green` (system green) |
| Read item opacity | 0.6 |
| Highlight: yellow | `.yellow.opacity(0.3)` |
| Highlight: green | `.green.opacity(0.3)` |
| Highlight: blue | `.blue.opacity(0.3)` |
| Highlight: pink | `.pink.opacity(0.3)` |
| Typography | System font (SF Pro via `.body`, `.title`, etc.) |

---

## 15. Starter Feeds (First Launch)

On first launch, if no feeds exist, offer to subscribe to these defaults:

```
AI / Tech
  - Hacker News          https://news.ycombinator.com/rss
  - Simon Willison       https://simonwillison.net/atom/everything/
  - The Verge AI         https://www.theverge.com/rss/ai-artificial-intelligence/index.xml
  - MIT Tech Review      https://www.technologyreview.com/feed/

Research
  - ArXiv cs.AI          https://rss.arxiv.org/rss/cs.AI
  - ArXiv cs.LG          https://rss.arxiv.org/rss/cs.LG

Newsletters
  - Interconnects        https://www.interconnects.ai/feed
  - The Batch            https://www.deeplearning.ai/the-batch/feed/

Reddit
  - r/MachineLearning    https://www.reddit.com/r/MachineLearning.rss
  - r/artificial         https://www.reddit.com/r/artificial.rss
```

---

## 16. Claude Code Workflow Instructions

### Starting a new phase

1. Read this document and the global `~/.claude/CLAUDE.md` rules.
2. If the Xcode project doesn't exist yet, scaffold it with the folder structure in Section 5.
3. Create the `Makefile` from Section 4a.
4. Ensure `xcbeautify` is installed (`brew install xcbeautify`).
5. Run `make build` to confirm the empty project compiles clean.

### During implementation

- Implement one architectural layer at a time (models, then repos, then services, then views).
- Run `make build` after every file or logical group of changes. Report the result.
- Run `make test` after adding or modifying any testable logic.
- Never skip the build step. If a build fails, fix it before moving on.
- Use `Logger` events for key operations (feed refresh, item save, search query). Verify with `log stream` when debugging runtime behavior.

### When SwiftUI falls short

- Try the pure SwiftUI approach first.
- If it doesn't work, describe the limitation and propose the smallest AppKit bridge.
- Wait for approval before adding any AppKit interop.

### Code quality checks

- Zero warnings on every build.
- All `Button` (never `onTapGesture` for interactive elements).
- All images have `.accessibilityLabel()`.
- Context menus on all list rows.
- Keyboard shortcuts match the table in Section 7f.
- Menu commands match Section 7g.
- One code path per action — the shortcut, the menu item, the button, and the context menu all call the same method on the ViewModel.

### Signing & distribution (Phase 5 only)

- Manual archive: Xcode > Product > Archive for one-off checks.
- Scripted archive: `xcodebuild archive` + `notarytool` for repeatable builds.
- Verify with: `codesign -dvvv path/to/LS-Freeder.app` and `plutil -lint path/to/entitlements.plist`.
- Required entitlements: `com.apple.security.network.client` (feed fetching), `com.apple.security.files.user-selected.read-write` (OPML import/export).

---

## 17. What This Doc Does NOT Cover

- **iOS/iPadOS version** — this doc is macOS-only. A future doc can extend to iOS with adaptive layouts.
- **Sync between devices** — the web app is the sync layer. This macOS app is standalone with local storage. CloudKit sync could be a future addition.
- **Email digests** — this is a server-side feature in the web app. The macOS app does not send email.
- **Multi-user auth** — the macOS app is single-user. No login, no registration, no CSRF.

---

## 18. Dependencies

| Package | Purpose | Source |
|---|---|---|
| FeedKit | RSS/Atom parsing | Swift Package Manager |
| (none else required) | SwiftData, WKWebView, Swift Charts, os.Logger are all system frameworks | — |

Keep dependencies minimal. Prefer system frameworks. Add a package only when there is no reasonable system equivalent.
