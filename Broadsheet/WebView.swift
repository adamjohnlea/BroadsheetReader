import SwiftUI
import SwiftData
import WebKit

/// Data passed back from JavaScript when a user creates a highlight.
struct HighlightSelection {
    let selectedText: String
    let prefixContext: String
    let suffixContext: String
}

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let highlights: [Highlight]

    /// Called when the user selects text and taps "Highlight" in the WebView.
    var onHighlightCreated: ((HighlightSelection) -> Void)?

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
        let doc = styledDocument(html)
        // Only reload if HTML content actually changed to preserve highlight state
        if context.coordinator.lastLoadedHTML != doc {
            context.coordinator.lastLoadedHTML = doc
            context.coordinator.pendingHighlights = highlights
            context.coordinator.parent = self
            webView.loadHTMLString(doc, baseURL: baseURL)
        } else {
            context.coordinator.parent = self
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView?
        var lastLoadedHTML: String?
        var pendingHighlights: [Highlight] = []

        init(parent: WebView) {
            self.parent = parent
        }

        // Restore highlights after page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            restoreHighlights()
        }

        private func restoreHighlights() {
            guard !pendingHighlights.isEmpty else { return }

            let highlightData: [[String: String]] = pendingHighlights.map { h in
                [
                    "id": h.persistentModelID.hashValue.description,
                    "text": h.selectedText,
                    "prefix": h.prefixContext,
                    "suffix": h.suffixContext,
                ]
            }

            guard let json = try? JSONSerialization.data(withJSONObject: highlightData),
                  let jsonString = String(data: json, encoding: .utf8) else { return }

            webView?.evaluateJavaScript("restoreHighlights(\(jsonString))") { _, _ in }
        }

        // Receive events from JavaScript
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }

            DispatchQueue.main.async { [self] in
                if type == "highlightCreated",
                   let text = body["text"] as? String,
                   let prefix = body["prefix"] as? String,
                   let suffix = body["suffix"] as? String {
                    let selection = HighlightSelection(
                        selectedText: text,
                        prefixContext: prefix,
                        suffixContext: suffix
                    )
                    parent.onHighlightCreated?(selection)
                }
            }
        }
    }

    // MARK: - HTML Document

    private func styledDocument(_ body: String) -> String {
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
        <body>\(body)
        \(highlightJavaScript)
        </body>
        </html>
        """
    }

    // MARK: - JavaScript

    private var highlightJavaScript: String {
        """
        <script>
        (function() {
            // Create selection toolbar
            const toolbar = document.createElement('div');
            toolbar.className = 'broadsheet-selection-toolbar';
            toolbar.innerHTML = '<button id="bsHighlightBtn">✨ Highlight</button>';
            document.body.appendChild(toolbar);

            // Show toolbar on text selection
            document.addEventListener('mouseup', function(e) {
                setTimeout(function() {
                    const sel = window.getSelection();
                    const text = sel.toString().trim();
                    if (text.length > 5 && !e.target.closest('.broadsheet-selection-toolbar')) {
                        const range = sel.getRangeAt(0);
                        const rect = range.getBoundingClientRect();
                        const toolbarHeight = 36;
                        toolbar.style.left = Math.max(4, rect.left + rect.width / 2 - 50) + 'px';
                        // Show below selection if too close to top, above otherwise
                        if (rect.top < toolbarHeight + 8) {
                            toolbar.style.top = (rect.bottom + 6) + 'px';
                        } else {
                            toolbar.style.top = (rect.top - toolbarHeight - 4) + 'px';
                        }
                        toolbar.classList.add('visible');
                    } else if (!e.target.closest('.broadsheet-selection-toolbar')) {
                        toolbar.classList.remove('visible');
                    }
                }, 10);
            });

            // Create highlight
            document.getElementById('bsHighlightBtn').addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                const sel = window.getSelection();
                const text = sel.toString().trim();
                if (!text) return;

                const range = sel.getRangeAt(0);
                const fullText = document.body.innerText;
                const selStart = fullText.indexOf(text);
                const prefix = selStart > 0 ? fullText.substring(Math.max(0, selStart - 20), selStart) : '';
                const suffix = fullText.substring(selStart + text.length, selStart + text.length + 20);

                // Wrap selection
                try {
                    const span = document.createElement('span');
                    span.className = 'broadsheet-highlight';
                    range.surroundContents(span);
                } catch(err) {
                    wrapRangeHighlight(range);
                }

                sel.removeAllRanges();
                toolbar.classList.remove('visible');

                window.webkit.messageHandlers.broadsheet.postMessage({
                    type: 'highlightCreated',
                    text: text,
                    prefix: prefix,
                    suffix: suffix
                });
            });
        })();

        // Wrap cross-element selections
        function wrapRangeHighlight(range) {
            const walker = document.createTreeWalker(
                range.commonAncestorContainer, NodeFilter.SHOW_TEXT, null
            );
            const textNodes = [];
            let node;
            while (node = walker.nextNode()) {
                if (range.intersectsNode(node)) textNodes.push(node);
            }
            textNodes.forEach(function(textNode) {
                const span = document.createElement('span');
                span.className = 'broadsheet-highlight';
                textNode.parentNode.insertBefore(span, textNode);
                span.appendChild(textNode);
            });
        }

        // Restore highlights from saved data
        function restoreHighlights(highlights) {
            const bodyText = document.body.innerText;
            highlights.forEach(function(h) {
                const idx = bodyText.indexOf(h.text);
                if (idx === -1) return;

                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
                let charCount = 0, node, startNode = null, startOffset = 0, endNode = null, endOffset = 0;

                while (node = walker.nextNode()) {
                    const nodeLen = node.textContent.length;
                    if (!startNode && charCount + nodeLen > idx) {
                        startNode = node;
                        startOffset = idx - charCount;
                    }
                    if (startNode && charCount + nodeLen >= idx + h.text.length) {
                        endNode = node;
                        endOffset = idx + h.text.length - charCount;
                        break;
                    }
                    charCount += nodeLen;
                }

                if (startNode && endNode) {
                    try {
                        const range = document.createRange();
                        range.setStart(startNode, startOffset);
                        range.setEnd(endNode, endOffset);
                        if (startNode === endNode) {
                            const span = document.createElement('span');
                            span.className = 'broadsheet-highlight';
                            range.surroundContents(span);
                        } else {
                            wrapRangeHighlight(range);
                        }
                    } catch(err) {}
                }
            });
        }
        </script>
        """
    }
}
