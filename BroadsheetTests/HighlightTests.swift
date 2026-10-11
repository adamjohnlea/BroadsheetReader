import Testing
import Foundation
import SwiftData
import WebKit
@testable import Broadsheet_Reader

// MARK: - Test Page Harness

/// Loads article HTML into a real WKWebView using the app's document builder and highlight script.
@MainActor
private final class ArticlePage: NSObject, WKNavigationDelegate {
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ html: String) async throws {
        let script = try WebView.highlightScript.get()
        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            webView.loadHTMLString(WebView.document(body: html, script: script), baseURL: nil)
        }
    }

    /// Simulates the user selecting from the `startOccurrence`-th `start` phrase through the
    /// `endOccurrence`-th `end` phrase, then tapping Highlight. Returns what would be saved.
    func highlight(from start: String, occurrence startOccurrence: Int = 0,
                   through end: String, occurrence endOccurrence: Int = 0) async throws -> HighlightSelection? {
        let result = try await webView.callAsyncJavaScript("""
            function findPoint(phrase, n, atEnd) {
                const walker = document.createTreeWalker(
                    document.getElementById('broadsheet-article-root'), NodeFilter.SHOW_TEXT);
                let node, count = 0;
                while ((node = walker.nextNode())) {
                    let i = node.data.indexOf(phrase);
                    while (i !== -1) {
                        if (count === n) return { node: node, offset: atEnd ? i + phrase.length : i };
                        count++;
                        i = node.data.indexOf(phrase, i + 1);
                    }
                }
                throw new Error('Phrase not found: ' + phrase);
            }
            const s = findPoint(start, startOccurrence, false);
            const e = findPoint(end, endOccurrence, true);
            const range = document.createRange();
            range.setStart(s.node, s.offset);
            range.setEnd(e.node, e.offset);
            return BroadsheetHighlights.createFromRange(range);
            """,
            arguments: ["start": start, "startOccurrence": startOccurrence,
                        "end": end, "endOccurrence": endOccurrence],
            contentWorld: .page
        )
        guard let saved = result as? [String: String],
              let text = saved["text"], let prefix = saved["prefix"], let suffix = saved["suffix"] else {
            return nil
        }
        return HighlightSelection(selectedText: text, prefixContext: prefix, suffixContext: suffix)
    }

    /// The article's canonical text with every painted highlight wrapped in [brackets].
    func paintedText() async throws -> String {
        let result = try await webView.callAsyncJavaScript("""
            const index = BroadsheetHighlights.buildIndex();
            const marked = index.starts.map(function(p) {
                return !!(p.node.parentElement && p.node.parentElement.closest('.broadsheet-highlight'));
            });
            // A space counts as highlighted when the characters on both sides are.
            for (let i = 0; i < marked.length; i++) {
                if (index.text[i] === ' ') {
                    marked[i] = i > 0 && i < marked.length - 1 && marked[i - 1] && marked[i + 1];
                }
            }
            let out = '';
            for (let i = 0; i < index.text.length; i++) {
                if (marked[i] && (i === 0 || !marked[i - 1])) out += '[';
                out += index.text[i];
                if (marked[i] && (i === index.text.length - 1 || !marked[i + 1])) out += ']';
            }
            return out.trim();
            """,
            arguments: [:],
            contentWorld: .page
        )
        guard let text = result as? String else {
            Issue.record("paintedText returned a non-string result")
            return ""
        }
        return text
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadContinuation?.resume()
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        loadContinuation?.resume(throwing: error)
        loadContinuation = nil
    }
}

private func makeHighlight(_ selection: HighlightSelection) -> Highlight {
    Highlight(
        selectedText: selection.selectedText,
        prefixContext: selection.prefixContext,
        suffixContext: selection.suffixContext
    )
}

// MARK: - Highlight Anchoring

@Suite("Highlight anchoring (WebKit)")
@MainActor
struct HighlightAnchoringTests {

    @Test("Saving a highlight captures its text and surrounding context")
    func savesTextAndContext() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox jumps over the lazy dog.</p>")

        let saved = try #require(try await page.highlight(from: "brown", through: "jumps"))

        #expect(saved.selectedText == "brown fox jumps")
        #expect(saved.prefixContext == "The quick ")
        #expect(saved.suffixContext == " over the lazy dog.")
        #expect(try await page.paintedText() == "The quick [brown fox jumps] over the lazy dog.")
    }

    @Test("A saved highlight is restored after the article reloads")
    func roundTrip() async throws {
        let html = "<p>The quick brown fox jumps over the lazy dog.</p>"
        let page = ArticlePage()
        try await page.load(html)
        let saved = try #require(try await page.highlight(from: "brown", through: "jumps"))

        try await page.load(html)
        let missing = try await WebView.applyHighlights([makeHighlight(saved)], in: page.webView)

        #expect(missing.isEmpty)
        #expect(try await page.paintedText() == "The quick [brown fox jumps] over the lazy dog.")
    }

    @Test("Highlighting a repeated phrase restores the occurrence the user chose")
    func repeatedPhraseRestoresChosenOccurrence() async throws {
        let html = "<p>Apple released a new Mac. Later, Apple released a new iPad.</p>"
        let page = ArticlePage()
        try await page.load(html)

        let saved = try #require(
            try await page.highlight(from: "Apple released", occurrence: 1, through: "Apple released", occurrence: 1)
        )
        #expect(saved.prefixContext.hasSuffix("Later, "))

        try await page.load(html)
        _ = try await WebView.applyHighlights([makeHighlight(saved)], in: page.webView)

        #expect(try await page.paintedText() == "Apple released a new Mac. Later, [Apple released] a new iPad.")
    }

    @Test("Whitespace-heavy HTML does not shift restored highlights")
    func whitespaceHeavyHTML() async throws {
        let html = """
            <ul>
                <li>One</li>
                <li>Two</li>
            </ul>
            <p>
                The quick   brown
                fox jumps over
                the lazy dog.
            </p>
            """
        let page = ArticlePage()
        try await page.load(html)
        let saved = try #require(try await page.highlight(from: "brown", through: "jumps"))
        #expect(saved.selectedText == "brown fox jumps")

        try await page.load(html)
        let missing = try await WebView.applyHighlights([makeHighlight(saved)], in: page.webView)

        #expect(missing.isEmpty)
        #expect(try await page.paintedText() == "One Two The quick [brown fox jumps] over the lazy dog.")
    }

    @Test("A selection spanning paragraphs and inline elements saves readable text and restores")
    func crossElementSelection() async throws {
        let html = "<p>First paragraph ends <b>here</b>.</p><p>Second paragraph <em>starts</em> now.</p>"
        let page = ArticlePage()
        try await page.load(html)

        let saved = try #require(try await page.highlight(from: "ends", through: "Second paragraph"))
        #expect(saved.selectedText == "ends here. Second paragraph")

        try await page.load(html)
        let missing = try await WebView.applyHighlights([makeHighlight(saved)], in: page.webView)

        #expect(missing.isEmpty)
        #expect(try await page.paintedText() == "First paragraph [ends here. Second paragraph] starts now.")
    }

    @Test("Text inside style elements is ignored when restoring")
    func styleTextIgnored() async throws {
        let page = ArticlePage()
        try await page.load("<style>/* Target phrase */</style><p>Find the Target phrase here.</p>")

        let highlight = Highlight(selectedText: "Target phrase")
        let missing = try await WebView.applyHighlights([highlight], in: page.webView)

        #expect(missing.isEmpty)
        #expect(try await page.paintedText() == "Find the [Target phrase] here.")
    }

    @Test("A highlight whose text is not in the article is reported missing")
    func missingHighlightReported() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox jumps over the lazy dog.</p>")

        let present = Highlight(selectedText: "lazy dog")
        let absent = Highlight(selectedText: "purple elephant")
        let missing = try await WebView.applyHighlights([present, absent], in: page.webView)

        #expect(missing == [1])
        #expect(try await page.paintedText() == "The quick brown fox jumps over the [lazy dog].")
    }

    @Test("Re-applying a smaller set removes highlights that were deleted")
    func deletedHighlightsAreCleared() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox jumps over the lazy dog.</p>")
        let fox = Highlight(selectedText: "brown fox")
        let dog = Highlight(selectedText: "lazy dog")

        _ = try await WebView.applyHighlights([fox, dog], in: page.webView)
        #expect(try await page.paintedText() == "The quick [brown fox] jumps over the [lazy dog].")

        _ = try await WebView.applyHighlights([fox], in: page.webView)
        #expect(try await page.paintedText() == "The quick [brown fox] jumps over the lazy dog.")
    }

    @Test("Highlights saved by the previous version still restore where they did before")
    func legacyHighlightRestores() async throws {
        // The old code saved trimmed selection text (with innerText line breaks between blocks)
        // and context taken around the first occurrence.
        let page = ArticlePage()
        try await page.load("<p>Apple released a new Mac.</p><p>Apple released a new iPad.</p>")

        let legacy = Highlight(selectedText: "new Mac.\n\nApple released", prefixContext: "Apple released a ",
                               suffixContext: " a new iPad.")
        let missing = try await WebView.applyHighlights([legacy], in: page.webView)

        #expect(missing.isEmpty)
        #expect(try await page.paintedText() == "Apple released a [new Mac. Apple released] a new iPad.")
    }

    @Test("Selections shorter than six characters are not saved")
    func shortSelectionIgnored() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox.</p>")

        let saved = try await page.highlight(from: "fox", through: "fox")

        #expect(saved == nil)
        #expect(try await page.paintedText() == "The quick brown fox.")
    }
}

// MARK: - Highlight Model & Search

@Suite("Highlights — model and search")
@MainActor
struct HighlightModelTests {

    /// An in-memory store with CloudKit sync disabled. The default (`.automatic`) attaches CloudKit
    /// mirroring from the host app's entitlements, which races store teardown and crashes Core Data
    /// ("No eligible connection available").
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FeedGroup.self, Feed.self, FeedItem.self, Bookmark.self, Highlight.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    /// Inserts an item with a bookmark holding one highlight.
    private func insertHighlightedItem(in context: ModelContext, text: String = "a highlighted passage",
                                       note: String? = nil) -> (FeedItem, Bookmark, Highlight) {
        let item = FeedItem(guid: UUID().uuidString, title: "Plain title", url: "https://example.com/a")
        context.insert(item)
        let bookmark = Bookmark(item: item)
        context.insert(bookmark)
        item.bookmark = bookmark
        let highlight = Highlight(selectedText: text, note: note, bookmark: bookmark)
        context.insert(highlight)
        return (item, bookmark, highlight)
    }

    @Test("Deleting a bookmark deletes its highlights")
    func bookmarkDeleteCascadesToHighlights() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (item, bookmark, _) = insertHighlightedItem(in: context)
        try context.save()

        item.bookmark = nil
        context.delete(bookmark)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Highlight>()) == 0)
    }

    @Test("Deleting an article deletes its bookmark and highlights")
    func itemDeleteCascadesToHighlights() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let (item, _, _) = insertHighlightedItem(in: context)
        try context.save()

        context.delete(item)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<Bookmark>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Highlight>()) == 0)
    }

    @Test("Search matches highlighted text, case-insensitively")
    func searchMatchesHighlightText() throws {
        let container = try makeContainer()
        let (item, _, _) = insertHighlightedItem(in: container.mainContext, text: "Swift Concurrency explained")

        #expect(SearchFilter.matches(item, query: "concurrency"))
        #expect(SearchFilter.matches(item, query: "SWIFT CONCURRENCY"))
    }

    @Test("Search matches a highlight's note")
    func searchMatchesHighlightNote() throws {
        let container = try makeContainer()
        let (item, _, _) = insertHighlightedItem(in: container.mainContext, note: "Revisit for the talk")

        #expect(SearchFilter.matches(item, query: "the talk"))
    }

    @Test("Search does not match text that appears nowhere on the article")
    func searchNoMatch() throws {
        let container = try makeContainer()
        let (item, _, _) = insertHighlightedItem(in: container.mainContext, note: "A note")

        #expect(!SearchFilter.matches(item, query: "nonexistent"))
    }
}
