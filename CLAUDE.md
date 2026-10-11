# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Broadsheet Reader** is a native macOS RSS reader app built with SwiftUI and SwiftData. A clean, focused reader with feed groups, read/unread tracking, bookmarks with notes, article highlights/annotations, full-text search, OPML import/export, and iCloud sync.

## Operating model

How we work together here. You are the senior engineer. I'm the project lead. I decide what we build and whether it's done. You decide how it's built. When a choice is mine, lay out the options with their consequences and let me pick. Don't pick for me and move on.

**What stays mine (never decide these alone):**
- What the app does and who it's for.
- What's stored, what syncs, what leaves the device.
- Whether a task is done.
- The written record of decisions, in DECISIONS.md.

**Always:**
- Explore and agree a plan before building. Use /plan for anything past a trivial change.
- Before you change build settings, the deployment target, the Swift language version, concurrency settings, entitlements, dependencies, or the data model, or before you delete any file, stop and ask. (The Data Layer note below already forbids data-model changes while the app is running. That stands.)
- Before you call anything done, show evidence: a clean build with no new warnings, tests that assert something, and a run on the Mac for the states that matter.
- When you state a fact about an API, an availability version, or a migration, cite the Apple doc page or WWDC session, or write a short proof I can run. Don't assert from memory.
- When I ask for something, tell me the strongest case against it before you build it. If you change a recommendation after I push, give me the reason. Don't just agree.
- Record each decision and its reason in DECISIONS.md, in my words.

Architecture lives in the Architecture section below. Decisions live in DECISIONS.md.

## Build Commands

Use `xcodebuild` via xcbeautify:

```sh
# Build
xcodebuild -project Broadsheet.xcodeproj -scheme Broadsheet -destination 'platform=macOS' build | xcbeautify

# Unit tests
xcodebuild -project Broadsheet.xcodeproj -scheme Broadsheet -destination 'platform=macOS' -only-testing:BroadsheetTests test | xcbeautify

# UI tests (only at handoff points — takes over the machine)
xcodebuild -project Broadsheet.xcodeproj -scheme Broadsheet -destination 'platform=macOS' -only-testing:BroadsheetUITests test | xcbeautify
```

## Architecture

The app uses SwiftUI + SwiftData throughout with CloudKit sync.

- **`BroadsheetApp.swift`** — App entry point, sets up `ModelContainer` with CloudKit. Falls back to local storage if iCloud is unavailable. Requests notification permission for dock badge. Registers Help window.
- **`ContentView.swift`** — Root `NavigationSplitView` (sidebar + article list + detail). Handles OPML import/export, background refresh, badge count, walkthrough, and help window.
- **`SidebarView.swift`** — Navigation items (Today, All Items, Bookmarks, Search), feed groups with collapse/expand, context menus, drag-and-drop reordering. Counts respect retention settings.
- **`ItemGridView.swift`** — Article list with All/Unread filter, retention filtering, context menus, keyboard navigation (Cmd+Up/Down).
- **`ArticleDetailView.swift`** — Article detail with HTML rendering, collapsible annotations section (notes + highlights), toolbar actions.
- **`WebView.swift`** — `WKWebView` wrapper with JavaScript bridge for article rendering and text highlighting. Coordinator handles bidirectional Swift-JS communication.
- **`SettingsView.swift`** — App settings (mark as read, refresh interval, retention, sync status).
- **`BroadsheetCommands.swift`** — Menu bar commands with keyboard shortcuts.
- **`WalkthroughView.swift`** — First-launch walkthrough with animated SF Symbols.
- **`HelpView.swift`** — In-app help window with 9 topic pages.

### Data Models

- **`Feed.swift`** — RSS/Atom feed with URL, title, favicon, fetch state, group association.
- **`FeedGroup.swift`** — Named group with sort order and collapse state.
- **`FeedItem.swift`** — Article with guid-based deduplication, read state, soft-delete.
- **`Bookmark.swift`** — Links a FeedItem to an optional user note. Has cascade relationship to Highlights.
- **`Highlight.swift`** — A highlighted text passage linked to a Bookmark, with selected text, prefix/suffix context for re-anchoring, and optional note.

### Services

- **`FeedFetcher.swift`** — Feed discovery, fetching, parsing pipeline. Parallel refresh. HTTPS upgrade.
- **`FeedParser.swift`** — Custom XMLParser supporting RSS 2.0 and Atom 1.0.
- **`OPMLHandler.swift`** — OPML 2.0 import/export with group structure.

## Data Layer

SwiftData is the persistence layer with CloudKit sync. All relationships are optional (CloudKit requirement). No `@Attribute(.unique)` — deduplication is logic-based via guid checking. Use `@Query` in views for reactive data fetching.

**Important:** Never switch branches or modify data model files while the app is running. SwiftData + CloudKit schema mismatches can corrupt or reset the database, including the CloudKit remote store.

## Key Product Requirements

- Three-column layout: sidebar + article list + article detail
- Feed groups with collapsible sections, unread count badges (retention-aware)
- Article list with favicon, serif titles, newspaper dateline dates, unread dots
- Article highlights: select text in WebView to save passages with notes
- Full-text search across title/summary/content/feed name/highlights/notes
- OPML import/export with group structure
- Background feed refresh (configurable: 15/30/60 min or manual)
- Bookmarks with optional notes and cascade-linked highlights
- Configurable article retention (7/30/90 days or forever)
- iCloud CloudKit sync with local fallback
- Share articles via system share sheet
- Liquid Glass accents on filter bar and toolbar

## CI

Xcode Cloud runs tests on push. The `ci_scripts/ci_post_clone.sh` script strips restricted entitlements (CloudKit, push) so the test runner can launch the app on CI.

## Design

- **Typography:** New York serif for article titles (list and detail), system font elsewhere
- **Accent color:** Green (#16a34a light, #22b658 dark) — used for unread dots, bookmark icons, highlight markers, sidebar badges
- **Dates:** Newspaper dateline format — "2:34 PM" for today, "13 APR" for this year, "13 APR 2025" for older
- **Liquid Glass:** Applied to filter bar (`.glassEffect`) and toolbar
- **Icons:** Custom-generated app icon set (newspaper + RSS signal badge)
