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
                    .id(item.persistentModelID)
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
    @AppStorage("annotationsExpanded") private var annotationsExpanded = true

    private static let dateline: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static func datelineString(from date: Date) -> String {
        dateline.string(from: date)
    }

    private var bookmarkHighlights: [Highlight] {
        item.bookmark?.highlights ?? []
    }

    private var hasAnnotations: Bool {
        item.bookmark != nil && (
            !(item.bookmark?.note?.isEmpty ?? true) || !bookmarkHighlights.isEmpty
        )
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

            // Collapsible annotations area (note + highlights)
            if item.bookmark != nil {
                Divider()
                AnnotationsSection(
                    bookmark: item.bookmark!,
                    isExpanded: $annotationsExpanded,
                    noteText: $noteText,
                    onDeleteHighlight: { highlight in
                        modelContext.delete(highlight)
                    }
                )
            }

            Divider()

            // Content
            if let content = item.content, !content.isEmpty {
                WebView(
                    html: content,
                    baseURL: URL(string: item.url),
                    highlights: bookmarkHighlights,
                    onHighlightCreated: { selection in
                        createHighlight(from: selection)
                    }
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

                Button {
                    item.isRead.toggle()
                } label: {
                    Label(
                        item.isRead ? "Mark as Unread" : "Mark as Read",
                        systemImage: item.isRead ? "envelope.badge" : "envelope.open"
                    )
                }
                .help(item.isRead ? "Mark as Unread" : "Mark as Read")

                if let url = URL(string: item.url) {
                    ShareLink(item: url, subject: Text(item.title)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .help("Share Article")

                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                    }
                    .help("Open in Browser")
                }
            }
        }
    }

    // MARK: - Actions

    private func createHighlight(from selection: HighlightSelection) {
        // Auto-bookmark if not already bookmarked
        if item.bookmark == nil {
            let bookmark = Bookmark(item: item)
            modelContext.insert(bookmark)
            item.bookmark = bookmark
        }

        let highlight = Highlight(
            selectedText: selection.selectedText,
            prefixContext: selection.prefixContext,
            suffixContext: selection.suffixContext,
            bookmark: item.bookmark
        )
        modelContext.insert(highlight)
        annotationsExpanded = true
    }

    private func toggleBookmark() {
        if let existing = item.bookmark {
            item.bookmark = nil
            modelContext.delete(existing)
            noteText = ""
        } else {
            let bookmark = Bookmark(item: item)
            modelContext.insert(bookmark)
            item.bookmark = bookmark
        }
    }
}

