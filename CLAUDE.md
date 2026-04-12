# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Broadsheet** is a native macOS/iOS RSS reader app built with SwiftUI and SwiftData. The product vision is described in `PROJECT.md` — an AI/tech news reader inspired by Reeder 5, with feed groups, read/unread tracking, bookmarks, full-text search, and email digests.

## Build Commands

No Makefile exists yet. Use `xcodebuild` via xcbeautify:

```sh
# Build
xcodebuild -project Broadsheet/Broadsheet.xcodeproj -scheme Broadsheet -destination 'platform=macOS' build | xcbeautify

# Unit tests
xcodebuild -project Broadsheet/Broadsheet.xcodeproj -scheme BroadsheetTests -destination 'platform=macOS' test | xcbeautify

# UI tests (only at handoff points)
xcodebuild -project Broadsheet/Broadsheet.xcodeproj -scheme BroadsheetUITests -destination 'platform=macOS' test | xcbeautify
```

Or use the `BuildProject` and `RunAllTests` MCP tools from xcode-tools when working inside Xcode.

## Architecture

The app uses SwiftUI + SwiftData throughout. Currently at initial scaffold — the data model and UI need to be built out per the spec in `PROJECT.md`.

- **`BroadsheetApp.swift`** — App entry point, sets up `ModelContainer` with `isStoredInMemoryOnly: false` for persistent SQLite storage.
- **`ContentView.swift`** — Root view, uses `NavigationSplitView` (sidebar + detail). All queries go through `@Query` on SwiftData models.
- **`Item.swift`** — Placeholder `@Model`. Replace with the real domain models: `Feed`, `FeedGroup`, `FeedItem`, `Bookmark`, `ReadStatus`.

## Data Layer

SwiftData is the persistence layer. Define all models with `@Model` and inject the shared `ModelContainer` from `BroadsheetApp`. Use `@Query` in views for reactive data fetching. Use `modelContext.insert` / `modelContext.delete` for mutations.

## Key Product Requirements (from PROJECT.md)

- Three-column layout: icon nav rail + sidebar (240px) + content area card grid
- Feed groups with collapsible sections, unread counts
- Card grid with favicon, title weight indicating read/unread state, OG image
- Full-text search across title/summary/content
- OPML import/export
- Background feed refresh (every 15–30 min)
- Bookmarks with optional notes
- Email digest (daily/weekly)
