import SwiftUI
import SwiftData
import WebKit

/// Data passed back from JavaScript when a user creates a highlight.
struct HighlightSelection {
    let selectedText: String
    let prefixContext: String
    let suffixContext: String
}

/// Errors raised by the article highlight system.
enum HighlightError: LocalizedError {
    /// `highlights.js` is missing from the app bundle.
    case scriptMissing
    /// The page's highlight script reported a failure.
    case scriptFailed(String)
    /// JavaScript returned a result in an unexpected shape.
    case unexpectedResult

    var errorDescription: String? {
        switch self {
        case .scriptMissing:
            "The highlighting script is missing from the app."
        case .scriptFailed(let message):
            "Highlighting failed: \(message)"
        case .unexpectedResult:
            "Highlighting returned an unexpected result."
        }
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let highlights: [Highlight]

    /// Called when the user selects text and taps "Highlight" in the WebView.
    var onHighlightCreated: ((HighlightSelection) -> Void)?
    /// Called after highlights are painted, with the IDs of highlights whose text could not be found.
    var onHighlightsApplied: ((Set<PersistentIdentifier>) -> Void)?
    /// Called when the highlight system fails.
    var onError: ((Error) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// The isolated JavaScript world the highlight system runs in.
    ///
    /// Article content runs in the page world, so it can't see this world's globals or post to
    /// its message handler. The DOM itself is shared by both worlds.
    static let contentWorld = WKContentWorld.world(name: "Broadsheet")

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: Self.configuration(for: context.coordinator))
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        // Only reload if HTML content actually changed to preserve highlight state
        if coordinator.lastLoadedHTML != html {
            coordinator.lastLoadedHTML = html
            coordinator.load(html: html, baseURL: baseURL)
        } else if coordinator.isLoaded,
                  coordinator.appliedHighlightIDs != highlights.map(\.persistentModelID) {
            // Highlights were added or deleted; repaint so the page matches the model.
            coordinator.applyHighlights()
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        var lastLoadedHTML: String?
        var isLoaded = false
        var appliedHighlightIDs: [PersistentIdentifier]?
        /// Opens links the reader clicks. Replaced in tests.
        var openExternally: (URL) -> Void = { NSWorkspace.shared.open($0) }
        private var applyTask: Task<Void, Never>?
        /// The URL of the article load in flight; the only main-frame navigation allowed.
        private var pendingLoadURL: URL?

        init(parent: WebView) {
            self.parent = parent
        }

        /// Loads an article into the web view.
        func load(html: String, baseURL: URL?) {
            guard let webView else { return }
            isLoaded = false
            pendingLoadURL = baseURL ?? URL(string: "about:blank")
            webView.loadHTMLString(WebView.document(body: html), baseURL: baseURL)
        }

        // MARK: Navigation Policy

        /// Keeps the pane on the article: clicked links open in the browser, and anything else
        /// the content tries (script redirects, meta refresh, form submissions) is cancelled.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
            guard let url = navigationAction.request.url else { return (.cancel, preferences) }

            if let frame = navigationAction.targetFrame {
                // Embeds such as video players load inside their own frame and need their own
                // scripts. Local frames (srcdoc, about:blank, data:) are written by the article
                // itself, so they stay script-free like the article.
                if !frame.isMainFrame {
                    preferences.allowsContentJavaScript = !Self.isLocalFrame(url)
                    return (.allow, preferences)
                }
                if url == pendingLoadURL {
                    pendingLoadURL = nil
                    return (.allow, preferences)
                }
                // In-page links, such as footnotes, scroll the article.
                if Self.isSameDocument(url, as: webView.url) {
                    return (.allow, preferences)
                }
            }

            switch navigationAction.navigationType {
            case .linkActivated:
                openLink(url)
            case .formSubmitted, .formResubmitted:
                // Forms can't be carried over to the browser; tell the reader nothing happened.
                NSSound.beep()
            default:
                break
            }
            return (.cancel, preferences)
        }

        private func openLink(_ url: URL) {
            guard let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else {
                NSSound.beep()
                return
            }
            openExternally(url)
        }

        /// Whether a frame at `url` holds content the article wrote rather than a remote page.
        private static func isLocalFrame(_ url: URL) -> Bool {
            ["about", "data", "blob", "javascript"].contains(url.scheme?.lowercased() ?? "")
        }

        /// Whether `url` points into `current` (the same page with a different `#fragment`).
        private static func isSameDocument(_ url: URL, as current: URL?) -> Bool {
            guard let current, url.fragment != nil else { return false }
            var lhs = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var rhs = URLComponents(url: current, resolvingAgainstBaseURL: false)
            lhs?.fragment = nil
            rhs?.fragment = nil
            return lhs != nil && lhs == rhs
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            if case .failure(let error) = WebView.highlightScript {
                parent.onError?(error)
                return
            }
            applyHighlights()
        }

        /// Repaints the page with the current highlights and reports any that could not be found.
        func applyHighlights() {
            guard let webView else { return }
            let highlights = parent.highlights
            let ids = highlights.map(\.persistentModelID)
            appliedHighlightIDs = ids

            applyTask?.cancel()
            applyTask = Task { [weak self] in
                do {
                    let missing = try await WebView.applyHighlights(highlights, in: webView)
                    guard !Task.isCancelled, let self else { return }
                    self.parent.onHighlightsApplied?(Set(missing.map { ids[$0] }))
                } catch {
                    guard !Task.isCancelled, let self else { return }
                    self.parent.onError?(error)
                }
            }
        }

        // Receive events from JavaScript
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            // The handler is only installed in the highlight world; check anyway.
            guard message.world == WebView.contentWorld, message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            switch type {
            case "highlightCreated":
                guard let text = body["text"] as? String,
                      let prefix = body["prefix"] as? String,
                      let suffix = body["suffix"] as? String else {
                    parent.onError?(HighlightError.unexpectedResult)
                    return
                }
                parent.onHighlightCreated?(HighlightSelection(
                    selectedText: text,
                    prefixContext: prefix,
                    suffixContext: suffix
                ))
            case "highlightError":
                let detail = body["message"] as? String ?? "Unknown error"
                parent.onError?(HighlightError.scriptFailed(detail))
            default:
                break
            }
        }
    }

    // MARK: - Highlight Script

    /// Paints `highlights` in a loaded article page.
    ///
    /// Replaces any highlights already painted, so the page always matches the given set.
    ///
    /// - Parameters:
    ///   - highlights: The highlights to paint.
    ///   - webView: A web view built from ``configuration(for:)`` showing a page built by ``document(body:)``.
    /// - Returns: Indices into `highlights` of the highlights whose text was not found.
    /// - Throws: A WebKit error if the script fails, or ``HighlightError/unexpectedResult``.
    static func applyHighlights(_ highlights: [Highlight], in webView: WKWebView) async throws -> [Int] {
        let payload: [[String: String]] = highlights.enumerated().map { index, h in
            [
                "id": String(index),
                "text": h.selectedText,
                "prefix": h.prefixContext,
                "suffix": h.suffixContext,
            ]
        }
        let result = try await webView.callAsyncJavaScript(
            "return BroadsheetHighlights.apply(highlights);",
            arguments: ["highlights": payload],
            contentWorld: contentWorld
        )
        guard let ids = result as? [String] else { throw HighlightError.unexpectedResult }
        return try ids.map { id in
            guard let index = Int(id), highlights.indices.contains(index) else {
                throw HighlightError.unexpectedResult
            }
            return index
        }
    }

    /// The configuration for article web views.
    ///
    /// Article JavaScript is off; the highlight script and the "broadsheet" message handler
    /// live in ``contentWorld``, which still runs. Embedded iframes get JavaScript back in
    /// ``Coordinator/webView(_:decidePolicyFor:preferences:)``.
    ///
    /// - Parameter coordinator: Receives messages from the highlight script.
    /// - Returns: A configuration for a new web view.
    static func configuration(for coordinator: Coordinator) -> WKWebViewConfiguration {
        let controller = WKUserContentController()
        controller.add(coordinator, contentWorld: contentWorld, name: "broadsheet")
        // If the script is missing the article still loads; didFinish surfaces the error.
        if case .success(let source) = highlightScript {
            controller.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd,
                                                  forMainFrameOnly: true, in: contentWorld))
        }
        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return config
    }

    /// The highlight system's JavaScript, loaded once from the app bundle.
    static let highlightScript: Result<String, Error> = Result {
        guard let url = Bundle.main.url(forResource: "highlights", withExtension: "js") else {
            throw HighlightError.scriptMissing
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - HTML Document

    /// Builds the full HTML page for an article.
    ///
    /// The article body is wrapped in a root element that scopes highlight anchoring,
    /// so the selection toolbar never counts as article text.
    ///
    /// - Parameter body: The article's HTML content.
    /// - Returns: A complete HTML document.
    static func document(body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        html {
            font-family: -apple-system, system-ui, sans-serif;
            font-size: 16px;
            line-height: 1.7;
        }
        body {
            margin: 0 auto;
            padding: 0 4px 40px 4px;
            max-width: 680px;
            color: #1a1a1a;
            background: transparent;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        @media (prefers-color-scheme: dark) {
            body { color: #e8e8e8; }
            img  { opacity: .88; }
            pre  { background: rgba(255,255,255,.07) !important; }
            code { background: rgba(255,255,255,.07) !important; }
        }
        h1,h2,h3,h4 { font-family: ui-serif, Georgia, serif; line-height: 1.25; font-weight: 700; }
        a  { color: #16a34a; }
        img, video { max-width: 100%; height: auto; border-radius: 6px; }
        figure { margin: 0; }
        pre  { overflow-x: auto; background: rgba(0,0,0,.04); padding: 12px; border-radius: 6px; }
        code { font-family: ui-monospace, monospace; font-size: .9em;
               background: rgba(0,0,0,.04); padding: 1px 4px; border-radius: 3px; }
        pre code { background: none; padding: 0; }
        blockquote { border-left: 3px solid #16a34a; margin-left: 0; padding-left: 16px;
                     color: #555; }
        @media (prefers-color-scheme: dark) { blockquote { color: #aaa; } }
        table { border-collapse: collapse; width: 100%; }
        th,td { border: 1px solid #ddd; padding: 6px 10px; }

        /* Highlight styles */
        .broadsheet-highlight {
            background: rgba(22, 163, 74, 0.2);
            border-bottom: 2px solid rgba(22, 163, 74, 0.5);
            padding: 1px 2px;
            border-radius: 2px;
            cursor: default;
        }

        /* Selection toolbar */
        .broadsheet-selection-toolbar {
            position: fixed;
            background: rgba(42, 42, 42, 0.95);
            border: 1px solid rgba(58, 58, 58, 1);
            border-radius: 8px;
            padding: 4px;
            box-shadow: 0 4px 16px rgba(0,0,0,0.3);
            z-index: 9999;
            display: none;
            font-family: -apple-system, system-ui, sans-serif;
        }
        .broadsheet-selection-toolbar.visible { display: flex; }
        .broadsheet-selection-toolbar button {
            display: flex; align-items: center; gap: 6px;
            padding: 6px 12px; border: none; background: transparent;
            color: #e8e8e8; font-size: 13px;
            font-family: -apple-system, system-ui, sans-serif;
            cursor: pointer; border-radius: 6px;
        }
        .broadsheet-selection-toolbar button:hover { background: #16a34a; color: white; }
        @media (prefers-color-scheme: light) {
            .broadsheet-selection-toolbar {
                background: rgba(255, 255, 255, 0.95);
                border: 1px solid rgba(220, 220, 220, 1);
            }
            .broadsheet-selection-toolbar button { color: #1a1a1a; }
        }
        </style>
        </head>
        <body>
        <div id="broadsheet-article-root">\(body)</div>
        </body>
        </html>
        """
    }
}
