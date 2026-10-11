# Decisions

New decisions go here, newest first, each with the date and the reason.

Decisions already baked into the app are described in CLAUDE.md:
- All SwiftData relationships optional and no `@Attribute(.unique)`, with logic-based deduplication via guid checking (CloudKit requirement). See the Data Layer section.
- Local storage fallback when iCloud is unavailable. See the Architecture section (`BroadsheetApp.swift`).
