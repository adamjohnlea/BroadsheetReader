# Broadsheet Reader

A native macOS RSS reader built with SwiftUI and SwiftData. Designed for AI and tech news, inspired by the clean aesthetic of Reeder 5.

![macOS](https://img.shields.io/badge/macOS-26.4+-black) ![Swift](https://img.shields.io/badge/Swift-5-orange) ![SwiftUI](https://img.shields.io/badge/SwiftUI-black) ![SwiftData](https://img.shields.io/badge/SwiftData-black) ![Tests](https://img.shields.io/badge/tests-139-green)

## Features

### Feed Management
- Add feeds by URL with automatic RSS/Atom autodiscovery
- Organize feeds into collapsible groups with drag-and-drop reordering
- OPML import and export with full group structure preservation
- Starter feed library with curated AI/tech sources for first-run onboarding
- Per-feed error tracking with UI indicators
- Guided walkthrough on first launch (also available from Help menu)
- Built-in Apple Help Book with documentation for all features

### Reading
- Three-column layout: sidebar, article list, and article detail
- Read/unread tracking with unread count badges and green indicator dots
- Keyboard navigation: `Cmd+↓` / `Cmd+↑` to move between articles
- Configurable auto-mark-as-read on article open
- "Mark All Read" per feed, group, or entire view
- Full HTML article rendering with dark mode support and serif headings
- Filter toggle between All and Unread items
- Share articles via the system share sheet (AirDrop, Messages, Mail, etc.)

### Search
- Full-text search across article titles, summaries, content, and feed names
- Case-insensitive, instant client-side filtering

### Bookmarks
- Bookmark any article with an optional user note
- Inline note editor with auto-save
- Dedicated bookmarks view (exempt from unread and retention filters)
- Note snippets shown in the article list

### Background Refresh
- Configurable automatic refresh interval: 15, 30, or 60 minutes (or manual only)
- Parallel feed fetching for fast updates
- Dock badge showing total unread count

### Sync
- iCloud CloudKit sync across devices
- Graceful fallback to local-only storage when iCloud is unavailable

### Article Retention
- Configurable retention window: 7, 30, 90 days, or forever
- Bookmarked articles are always preserved regardless of retention setting
- Soft-delete support — deleted articles stay hidden even after re-sync

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+Shift+N` | Add Feed |
| `Cmd+R` | Refresh All Feeds |
| `Cmd+1` | Go to Today |
| `Cmd+2` | Go to All Items |
| `Cmd+3` | Go to Bookmarks |
| `Cmd+F` | Search |
| `Cmd+↓` | Next Article |
| `Cmd+↑` | Previous Article |
| `Cmd+,` | Settings |

## Settings

- **Mark as read on open** — automatically mark articles read when selected
- **Refresh interval** — 15 / 30 / 60 minutes, or manual only
- **Article retention** — 7 / 30 / 90 days, or forever
- **iCloud sync status** — shows current sync state

## Technical Details

### Architecture
- **SwiftUI** for all views with `NavigationSplitView` three-column layout
- **SwiftData** with `@Model` classes and `@Query`-driven reactive UI
- **CloudKit** integration with optional relationships (required for CloudKit schema compatibility)
- **Strict concurrency** with MainActor as the default isolation level
- No third-party dependencies — built entirely on Apple frameworks

### Data Models
- `Feed` — RSS/Atom feed with URL, title, favicon, fetch state, and group association
- `FeedGroup` — named group with sort order and collapse state
- `FeedItem` — article with guid-based deduplication, read state, and soft-delete support
- `Bookmark` — links a `FeedItem` to an optional user note

### Feed Parsing
- Custom `XMLParser`-based parser supporting both **RSS 2.0** and **Atom 1.0**
- Handles `content:encoded`, `dc:creator`, `media:content`, enclosures, and multiple date formats
- Automatic HTTPS upgrade for all feed URLs
- HTML-to-plaintext conversion with entity decoding for summaries
- GUID deduplication with fallback to link URL

### Capabilities & Entitlements
- App Sandbox enabled
- Network client access (for fetching feeds)
- iCloud CloudKit container: `iCloud.com.adamjohnlea.Broadsheet`
- Push notification entitlement (for dock badge support)

## Build

Requires Xcode and [xcbeautify](https://github.com/cpisciotta/xcbeautify) (`brew install xcbeautify`).

```sh
# Build
xcodebuild -project Broadsheet/Broadsheet.xcodeproj \
  -scheme Broadsheet -destination 'platform=macOS' build | xcbeautify

# Run unit tests
xcodebuild -project Broadsheet/Broadsheet.xcodeproj \
  -scheme BroadsheetTests -destination 'platform=macOS' test | xcbeautify
```

## Tests

### Unit Tests

82 tests across 9 suites using the Swift Testing framework:

- **FeedParserRSSTests** — RSS 2.0 parsing, date handling, HTML stripping, entity decoding
- **FeedParserAtomTests** — Atom 1.0 parsing, ISO 8601 dates, content vs summary precedence
- **OPMLHandlerTests** — export/import round-tripping, XML escaping, group structure
- **ModelTests** — SwiftData schema and in-memory container initialization
- **ItemFilteringTests** — view-based filtering (today, all, feed, group, unread)
- **RetentionTests** — age-based filtering, bookmark exemption, configurable retention
- **RetentionFilterTests** — display-time retention logic
- **DeletionTests** — soft-delete exclusion
- **FeedFetcherLogicTests** — deduplication and fetch pipeline logic

### UI Tests

57 tests across 13 suites using XCTest/XCUIApplication:

- **AppLaunchTests** — app launches, sidebar visible, toolbar buttons present
- **SidebarNavigationTests** — click and keyboard shortcut navigation between sections
- **AddFeedSheetTests** — open/close sheet, URL field validation, button enable/disable states
- **NewGroupSheetTests** — open/close sheet, name field validation, create button states
- **SearchTests** — search field exists, typing shows results, keyboard shortcut focuses field
- **SettingsTests** — opens via shortcut, contains all sections and controls
- **FilterBarTests** — visible on correct views, hidden on bookmarks/search, toggle stability
- **EmptyStateTests** — empty states for search, all items, bookmarks, detail pane
- **FeedsMenuTests** — menu bar items exist, navigation via menu works
- **OPMLMenuTests** — import/export menu items present
- **RefreshTests** — toolbar button and keyboard shortcut
- **KeyboardShortcutTests** — all shortcuts open correct UI
- **LaunchPerformanceTests** — launch time measurement

## Starter Feeds

First launch offers a curated set of Apple feeds:

| Group | Feeds |
|---|---|
| Apple | Apple Newsroom, Daring Fireball, MacRumors, Six Colors |

## License

All rights reserved.
