import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(styledDocument(html), baseURL: baseURL)
    }

    // Wraps raw HTML fragment in a full document with typography + dark-mode CSS
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
            line-height: 1.65;
        }
        body {
            margin: 0;
            padding: 0 4px 40px 4px;
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
        h1,h2,h3,h4 { line-height: 1.25; }
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
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}
