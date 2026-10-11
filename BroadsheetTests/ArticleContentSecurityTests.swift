import Testing
import Foundation
import WebKit
@testable import Broadsheet_Reader

private typealias ArticleWebView = Broadsheet_Reader.WebView

// MARK: - Test Server

/// Serves `probe://` URLs and records every request the page makes.
@MainActor
private final class TestServer: NSObject, WKURLSchemeHandler {
    /// Pages served by URL path. Anything else gets an empty 200, except `/broken`, which fails.
    var pages: [String: String] = [:]
    private(set) var requests: [URLRequest] = []

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let request = urlSchemeTask.request
        requests.append(request)
        guard let url = request.url else { return }
        if url.path == "/broken" {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let body = pages[url.path] ?? ""
        let mime = url.path.hasSuffix(".html") ? "text/html" : "application/octet-stream"
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: mime,
                                             expectedContentLength: body.utf8.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(Data(body.utf8))
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    func requested(_ path: String) -> Bool {
        requests.contains { $0.url?.path == path }
    }
}

// MARK: - Article Page

/// An article page wired like production: the app's configuration, with the real coordinator as
/// message handler and navigation delegate. Links the coordinator would open are recorded instead.
///
/// An https page won't load or fetch() the custom probe:// scheme, so tests that load iframes
/// or other pages from the test server use a probe:// base URL.
@MainActor
private final class ArticlePage {
    let server = TestServer()
    let webView: WKWebView
    let coordinator: ArticleWebView.Coordinator
    private let recorder: Recorder

    init() {
        let recorder = Recorder()
        self.recorder = recorder
        coordinator = ArticleWebView.Coordinator(parent: ArticleWebView(
            html: "", baseURL: nil, highlights: [],
            onHighlightCreated: { recorder.created.append($0.selectedText) },
            onHighlightsApplied: { _ in },
            onError: { recorder.errors.append($0.localizedDescription) }
        ))
        coordinator.openExternally = { recorder.opened.append($0) }

        let config = ArticleWebView.configuration(for: coordinator)
        config.setURLSchemeHandler(server, forURLScheme: "probe")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
        webView.navigationDelegate = coordinator
        coordinator.webView = webView
    }

    var created: [String] { recorder.created }
    var errors: [String] { recorder.errors }
    var opened: [URL] { recorder.opened }

    /// Loads `html` through the coordinator, as `WebView.updateNSView` does.
    func load(_ html: String, baseURL: String? = "https://example.com/article") async throws {
        coordinator.load(html: html, baseURL: baseURL.flatMap(URL.init(string:)))
        try await waitUntil("article load") { self.coordinator.isLoaded }
    }

    /// Runs `body` in the highlight script's world, where the app's own code runs.
    @discardableResult
    func run(_ body: String) async throws -> Any? {
        try await webView.callAsyncJavaScript(body, arguments: [:], contentWorld: ArticleWebView.contentWorld)
    }

    /// Clicks the element with `id`, the way a reader would.
    func click(_ id: String) async throws {
        try await run("document.getElementById('\(id)').click();")
    }

    /// Polls `condition` until it holds or two seconds pass.
    func waitUntil(_ what: String, _ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for \(what)")
    }

    /// Gives the page time to do something it should not be able to do.
    func settle() async throws {
        try await Task.sleep(for: .milliseconds(500))
    }

    final class Recorder {
        var created: [String] = []
        var errors: [String] = []
        var opened: [URL] = []
    }
}

/// Posts a fake highlight to the "broadsheet" bridge.
private let spoofHighlight = """
    window.webkit.messageHandlers.broadsheet.postMessage(
        {type:'highlightCreated', text:'INJECTED', prefix:'', suffix:''})
    """

// MARK: - Highlight Bridge

@Suite("Article content can't reach the highlight bridge")
@MainActor
struct HighlightBridgeIsolationTests {

    @Test("The app's Highlight button still reaches the bridge")
    func toolbarReachesBridge() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox jumps over the lazy dog.</p>")

        try await page.run("""
            const text = document.querySelector('#broadsheet-article-root p').firstChild;
            const range = document.createRange();
            range.setStart(text, 4);
            range.setEnd(text, 19);
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
            document.getElementById('bsHighlightBtn').click();
            """)

        try await page.waitUntil("highlight") { !page.created.isEmpty }
        #expect(page.created == ["quick brown fox"])
    }

    @Test("An inline <script> can't post a highlight")
    func inlineScriptBlocked() async throws {
        let page = ArticlePage()
        try await page.load("<p>Text.</p><script>\(spoofHighlight);</script>")
        try await page.settle()
        #expect(page.created.isEmpty)
    }

    @Test("An inline <script> can't raise the error alert")
    func inlineScriptErrorBlocked() async throws {
        let page = ArticlePage()
        try await page.load("""
            <script>window.webkit.messageHandlers.broadsheet.postMessage(
                {type:'highlightError', message:'Your iCloud session expired'});</script>
            """)
        try await page.settle()
        #expect(page.errors.isEmpty)
    }

    @Test("An event-handler attribute can't post a highlight")
    func eventHandlerBlocked() async throws {
        let page = ArticlePage()
        try await page.load(#"<img src="probe://cdn/broken" onerror="\#(spoofHighlight)">"#,
                            baseURL: "probe://example.com/article")
        try await page.waitUntil("image request") { page.server.requested("/broken") }
        try await page.settle()
        #expect(page.created.isEmpty)
    }

    @Test("An iframe can't post a highlight")
    func iframeBlocked() async throws {
        let page = ArticlePage()
        page.server.pages["/embed.html"] = "<script>\(spoofHighlight);</script>"
        try await page.load(#"<iframe src="probe://thirdparty/embed.html"></iframe>"#,
                            baseURL: "probe://example.com/article")
        try await page.waitUntil("iframe request") { page.server.requested("/embed.html") }
        try await page.settle()
        #expect(page.created.isEmpty)
    }

    @Test("Article script can't replace the highlight code")
    func highlightCodeCannotBeHijacked() async throws {
        let page = ArticlePage()
        try await page.load("""
            <p>The quick brown fox jumps over the lazy dog.</p>
            <script>
            Object.defineProperty(window, 'BroadsheetHighlights', {
                get: function() { return { apply: function(h) { return h.map(function(x) { return x.id; }); } }; },
                set: function(v) {}
            });
            </script>
            """)
        let missing = try await ArticleWebView.applyHighlights([Highlight(selectedText: "lazy dog")],
                                                               in: page.webView)
        #expect(missing.isEmpty)
    }
}

// MARK: - Navigation

@Suite("Article content can't navigate the reader pane")
@MainActor
struct ArticleNavigationPolicyTests {

    @Test("An article with no URL still loads")
    func loadsWithoutBaseURL() async throws {
        let page = ArticlePage()
        try await page.load("<p>Hello</p>", baseURL: nil)
        let text = try await page.run("return document.body.innerText;") as? String
        #expect(text?.contains("Hello") == true)
    }

    @Test("A clicked link opens in the browser and the article stays")
    func clickedLinkOpensInBrowser() async throws {
        let page = ArticlePage()
        try await page.load(#"<p><a id="l" href="https://example.org/story">Read more</a></p>"#)

        try await page.click("l")

        try await page.waitUntil("link opened") { !page.opened.isEmpty }
        try await page.settle()
        #expect(page.opened == [URL(string: "https://example.org/story")])
        #expect(page.webView.url == URL(string: "https://example.com/article"))
        #expect(page.errors.isEmpty)
    }

    @Test("A link that opens a new window opens once in the browser")
    func newWindowLinkOpensInBrowser() async throws {
        let page = ArticlePage()
        try await page.load(#"<a id="l" href="https://example.org/video" target="_blank">Watch</a>"#)

        try await page.click("l")

        try await page.waitUntil("link opened") { !page.opened.isEmpty }
        try await page.settle()
        #expect(page.opened == [URL(string: "https://example.org/video")])
    }

    @Test("A footnote link scrolls within the article")
    func footnoteLinkStaysInPage() async throws {
        let page = ArticlePage()
        try await page.load(##"<p><a id="l" href="#fn1">1</a></p><p id="fn1">Footnote.</p>"##)

        try await page.click("l")

        try await page.waitUntil("fragment navigation") { page.webView.url?.fragment == "fn1" }
        #expect(page.opened.isEmpty)
    }

    @Test("A link with an unsupported scheme is not opened")
    func unsupportedSchemeNotOpened() async throws {
        let page = ArticlePage()
        try await page.load(#"<a id="l" href="file:///etc/hosts">hosts</a>"#)

        try await page.click("l")

        try await page.settle()
        #expect(page.opened.isEmpty)
        #expect(page.webView.url == URL(string: "https://example.com/article"))
    }

    @Test("A script can't redirect the pane")
    func scriptRedirectBlocked() async throws {
        let page = ArticlePage()
        page.server.pages["/login.html"] = "<h1>Sign in</h1>"
        try await page.load("<script>location.href = 'probe://evil/login.html';</script>",
                            baseURL: "probe://example.com/article")
        try await page.settle()
        #expect(!page.server.requested("/login.html"))
        #expect(page.webView.url == URL(string: "probe://example.com/article"))
    }

    @Test("A meta refresh can't redirect the pane")
    func metaRefreshBlocked() async throws {
        let page = ArticlePage()
        page.server.pages["/login.html"] = "<h1>Sign in</h1>"
        try await page.load(#"<meta http-equiv="refresh" content="0;url=probe://evil/login.html"><p>Hi</p>"#,
                            baseURL: "probe://example.com/article")
        try await page.settle()
        #expect(!page.server.requested("/login.html"))
        #expect(page.webView.url == URL(string: "probe://example.com/article"))
    }

    @Test("A form can't be submitted, by script or by the reader")
    func formSubmissionBlocked() async throws {
        let page = ArticlePage()
        try await page.load("""
            <form action="probe://collector/submit" method="post">
                <input name="email" value="me@example.com"><button id="s">Subscribe</button>
            </form>
            <script>document.forms[0].submit();</script>
            """, baseURL: "probe://example.com/article")

        try await page.click("s")

        try await page.settle()
        #expect(!page.server.requested("/submit"))
        #expect(page.opened.isEmpty)
        #expect(page.webView.url == URL(string: "probe://example.com/article"))
    }

    @Test("Embedded iframes still load")
    func iframesLoad() async throws {
        let page = ArticlePage()
        try await page.load(#"<iframe src="probe://video/embed.html"></iframe>"#,
                            baseURL: "probe://example.com/article")
        try await page.waitUntil("iframe request") { page.server.requested("/embed.html") }
        #expect(page.server.requested("/embed.html"))
    }
}

// MARK: - Article JavaScript

@Suite("Article scripts don't run; embeds keep theirs")
@MainActor
struct ArticleJavaScriptPolicyTests {

    @Test("Scripts and event handlers in the article don't run")
    func articleScriptsDontRun() async throws {
        let page = ArticlePage()
        try await page.load("""
            <script>fetch('probe://tracker/script');</script>
            <img src="probe://cdn/broken" onerror="fetch('probe://tracker/onerror')">
            """, baseURL: "probe://example.com/article")
        try await page.waitUntil("image request") { page.server.requested("/broken") }
        try await page.settle()
        #expect(!page.server.requested("/script"))
        #expect(!page.server.requested("/onerror"))
    }

    @Test("Scripts inside an embedded iframe run")
    func embedScriptsRun() async throws {
        let page = ArticlePage()
        page.server.pages["/embed.html"] = "<script>fetch('probe://video/player');</script>"
        try await page.load(#"<iframe src="probe://video/embed.html"></iframe>"#,
                            baseURL: "probe://example.com/article")
        try await page.waitUntil("embed script") { page.server.requested("/player") }
        #expect(page.server.requested("/player"))
    }

    @Test("Scripts in an iframe the article writes itself (srcdoc) don't run")
    func srcdocScriptsDontRun() async throws {
        let page = ArticlePage()
        try await page.load(#"<iframe srcdoc="<script>fetch('probe://tracker/srcdoc')</script>"></iframe>"#,
                            baseURL: "probe://example.com/article")
        try await page.settle()
        #expect(!page.server.requested("/srcdoc"))
    }

    @Test("Highlights still paint with article JavaScript off")
    func highlightsStillWork() async throws {
        let page = ArticlePage()
        try await page.load("<p>The quick brown fox jumps over the lazy dog.</p>")
        let missing = try await ArticleWebView.applyHighlights([Highlight(selectedText: "brown fox")],
                                                               in: page.webView)
        #expect(missing.isEmpty)
        let painted = try await page.run(
            "return document.querySelector('.broadsheet-highlight')?.textContent;") as? String
        #expect(painted == "brown fox")
    }
}
