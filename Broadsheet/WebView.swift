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

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "broadsheet")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
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
            coordinator.isLoaded = false
            let script: String
            switch Self.highlightScript {
            case .success(let source):
                script = source
            case .failure:
                // The article still loads; the error is surfaced to the user in didFinish.
                script = ""
            }
            webView.loadHTMLString(Self.document(body: html, script: script), baseURL: baseURL)
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
        private var applyTask: Task<Void, Never>?

        init(parent: WebView) {
            self.parent = parent
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
            guard let body = message.body as? [String: Any],
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
                // Not a Broadsheet message; feed content can post to the same handler.
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
    ///   - webView: A web view showing a page built by ``document(body:script:)``.
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
            contentWorld: .page
        )
        guard let ids = result as? [String] else { throw HighlightError.unexpectedResult }
        return try ids.map { id in
            guard let index = Int(id), highlights.indices.contains(index) else {
                throw HighlightError.unexpectedResult
            }
            return index
        }
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
    /// so the script and selection toolbar never count as article text.
    ///
    /// - Parameters:
    ///   - body: The article's HTML content.
    ///   - script: The highlight system's JavaScript source.
    /// - Returns: A complete HTML document.
    static func document(body: String, script: String) -> String {
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
        <script>\(script)</script>
        </body>
        </html>
        """
    }
}
