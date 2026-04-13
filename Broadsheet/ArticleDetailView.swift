import SwiftUI
import SwiftData
import AppKit

struct ArticleDetailView: View {
    let item: FeedItem?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let item {
                ArticleReader(item: item)
                    .id(item.persistentModelID)  // force re-render on item change
            } else {
                ContentUnavailableView("Select an Article", systemImage: "newspaper",
                                       description: Text("Choose something to read from the list."))
            }
        }
    }
}

// MARK: - Reader

private struct ArticleReader: View {
    let item: FeedItem
    @Environment(\.modelContext) private var modelContext
    @State private var noteText: String = ""

    // Newspaper dateline: "13 April 2026"
    private static let dateline: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static func datelineString(from date: Date) -> String {
        dateline.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.system(.title2, design: .serif))
                    .fontWeight(.bold)
                    .textSelection(.enabled)

                HStack(spacing: 6) {
                    FeedFavicon(urlString: item.feed?.faviconURL)
                    Text(item.feed?.title ?? "Unknown Feed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let author = item.author, !author.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let date = item.publishedAt {
                        Text(Self.datelineString(from: date))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Bookmark note (only shown when bookmarked)
            if item.bookmark != nil {
                Divider()
                BookmarkNoteEditor(bookmark: item.bookmark!, noteText: $noteText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }

            Divider()

            // Content
            if let content = item.content, !content.isEmpty {
                WebView(
                    html: content,
                    baseURL: URL(string: item.url)
                )
                .padding(.horizontal, 20)
            } else if let summary = item.summary, !summary.isEmpty {
                ScrollView {
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "No Content",
                    systemImage: "doc.text",
                    description: Text("Open in browser to read the full article.")
                )
            }
        }
        .onAppear { noteText = item.bookmark?.note ?? "" }
        .onChange(of: item.bookmark?.persistentModelID) { _, _ in
            noteText = item.bookmark?.note ?? ""
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    toggleBookmark()
                } label: {
                    Label(
                        item.bookmark != nil ? "Remove Bookmark" : "Bookmark",
                        systemImage: item.bookmark != nil ? "bookmark.fill" : "bookmark"
                    )
                    .foregroundStyle(item.bookmark != nil ? .accent : .secondary)
                }
                .help(item.bookmark != nil ? "Remove Bookmark" : "Add Bookmark")
                .buttonStyle(.glass)

                Button {
                    item.isRead.toggle()
                } label: {
                    Label(
                        item.isRead ? "Mark as Unread" : "Mark as Read",
                        systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                    )
                }
                .help(item.isRead ? "Mark as Unread" : "Mark as Read")
                .buttonStyle(.glass)

                if let url = URL(string: item.url) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .help("Open in Browser")
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func toggleBookmark() {
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

// MARK: - Bookmark Note Editor

private struct BookmarkNoteEditor: View {
    let bookmark: Bookmark
    @Binding var noteText: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.accent)
                .font(.caption)
                .padding(.top, 3)

            ZStack(alignment: .topLeading) {
                if noteText.isEmpty && !isFocused {
                    Text("Add a note…")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                TextEditor(text: $noteText)
                    .font(.callout)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 36, maxHeight: 120)
                    .onChange(of: noteText) { _, newValue in
                        bookmark.note = newValue.isEmpty ? nil : newValue
                    }
            }
        }
    }
}
