# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Broadsheet** is a native macOS RSS reader app built with SwiftUI and SwiftData. An AI/tech news reader inspired by Reeder 5, with feed groups, read/unread tracking, bookmarks with notes, full-text search, OPML import/export, and iCloud sync.

## Build Commands

Use `xcodebuild` via xcbeautify:

```sh
# Build
xcodebuild -project Broadsheet.xcodeproj -scheme Broadsheet -destination 'platform=macOS' build | xcbeautify

# Unit tests
xcodebuild -project Broadsheet.xcodeproj -scheme BroadsheetTests -destination 'platform=macOS' test | xcbeautify

# UI tests (only at handoff points — takes over the machine)
xcodebuild -project Broadsheet.xcodeproj -scheme BroadsheetUITests -destination 'platform=macOS' test | xcbeautify
```

## Architecture

The app uses SwiftUI + SwiftData throughout with CloudKit sync.

- **`BroadsheetApp.swift`** — App entry point, sets up `ModelContainer` with CloudKit. Falls back to local storage if iCloud is unavailable. Requests notification permission for dock badge.
- **`ContentView.swift`** — Root `NavigationSplitView` (sidebar + article list + detail). Handles OPML import/export, background refresh, and badge count.
- **`SidebarView.swift`** — Navigation items (Today, All Items, Bookmarks, Search), feed groups with collapse/expand, context menus, drag-and-drop reordering.
- **`ItemGridView.swift`** — Article list with All/Unread filter, retention filtering, and context menus.
- **`ArticleDetailView.swift`** — Article detail with HTML rendering, bookmark note editor, toolbar actions.
- **`WebView.swift`** — `WKWebView` wrapper for rendering article HTML content.
- **`SettingsView.swift`** — App settings (mark as read, refresh interval, retention, sync status).
- **`BroadsheetCommands.swift`** — Menu bar commands with keyboard shortcuts.

### Data Models

- **`Feed.swift`** — RSS/Atom feed with URL, title, favicon, fetch state, group association.
- **`FeedGroup.swift`** — Named group with sort order and collapse state.
- **`FeedItem.swift`** — Article with guid-based deduplication, read state, soft-delete.
- **`Bookmark.swift`** — Links a FeedItem to an optional user note.

### Services

- **`FeedFetcher.swift`** — Feed discovery, fetching, parsing pipeline. Parallel refresh. HTTPS upgrade.
- **`FeedParser.swift`** — Custom XMLParser supporting RSS 2.0 and Atom 1.0.
- **`OPMLHandler.swift`** — OPML 2.0 import/export with group structure.

## Data Layer

SwiftData is the persistence layer with CloudKit sync. All relationships are optional (CloudKit requirement). No `@Attribute(.unique)` — deduplication is logic-based via guid checking. Use `@Query` in views for reactive data fetching.

## Key Product Requirements

- Three-column layout: sidebar + article list + article detail
- Feed groups with collapsible sections, unread count badges
- Article list with favicon, title weight indicating read/unread state
- Full-text search across title/summary/content/feed name
- OPML import/export with group structure
- Background feed refresh (configurable: 15/30/60 min or manual)
- Bookmarks with optional notes
- Configurable article retention (7/30/90 days or forever)
- iCloud CloudKit sync with local fallback

## CI

Xcode Cloud runs tests on push. The `ci_scripts/ci_post_clone.sh` script strips restricted entitlements (CloudKit, push) so the test runner can launch the app on CI.
