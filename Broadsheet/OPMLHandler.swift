import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - FileDocument

struct OPMLDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.xml]

    var content: String

    init(content: String = "") { self.content = content }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(content.utf8))
    }
}

// MARK: - Export

enum OPMLHandler {

    static func export(feedGroups: [FeedGroup], ungroupedFeeds: [Feed]) -> String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<opml version="2.0">"#,
            "  <head><title>Broadsheet Subscriptions</title></head>",
            "  <body>",
        ]

        for group in feedGroups.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let name = esc(group.name)
            lines.append("    <outline text=\"\(name)\" title=\"\(name)\">")
            for feed in (group.feeds ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }) {
                lines.append(feedLine(feed, indent: "      "))
            }
            lines.append("    </outline>")
        }

        for feed in ungroupedFeeds.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            lines.append(feedLine(feed, indent: "    "))
        }

        lines += ["  </body>", "</opml>"]
        return lines.joined(separator: "\n")
    }

    private static func feedLine(_ feed: Feed, indent: String) -> String {
        let t = esc(feed.title)
        let u = esc(feed.url)
        let s = esc(feed.siteURL ?? "")
        return "\(indent)<outline type=\"rss\" text=\"\(t)\" title=\"\(t)\" xmlUrl=\"\(u)\" htmlUrl=\"\(s)\"/>"
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - Import

    struct ImportedFeed {
        let title: String
        let url: String
        let groupName: String?
    }

    static func parse(_ content: String) -> [ImportedFeed] {
        guard let data = content.data(using: .utf8) else { return [] }
        return OPMLParser().parse(data: data)
    }
}

// MARK: - OPML XML Parser

private final class OPMLParser: NSObject, XMLParserDelegate {
    private var results: [OPMLHandler.ImportedFeed] = []
    private var outlineDepth = 0
    private var currentGroupName: String?

    func parse(data: Data) -> [OPMLHandler.ImportedFeed] {
        let p = XMLParser(data: data)
        p.delegate = self
        p.parse()
        return results
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes attrs: [String: String] = [:]) {
        guard name == "outline" else { return }
        outlineDepth += 1

        let xmlURL = (attrs["xmlUrl"] ?? attrs["xmlurl"] ?? "").trimmingCharacters(in: .whitespaces)
        let text   = (attrs["text"] ?? attrs["title"] ?? "").trimmingCharacters(in: .whitespaces)

        if !xmlURL.isEmpty {
            results.append(.init(title: text.isEmpty ? xmlURL : text,
                                 url: xmlURL,
                                 groupName: currentGroupName))
        } else if outlineDepth == 1 {
            currentGroupName = text.isEmpty ? nil : text
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        guard name == "outline" else { return }
        if outlineDepth == 1 { currentGroupName = nil }
        outlineDepth -= 1
    }
}
