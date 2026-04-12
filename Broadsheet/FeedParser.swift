import Foundation

// MARK: - Output types

struct ParsedFeed {
    let title: String
    let siteURL: String?
    let items: [ParsedItem]
}

struct ParsedItem {
    let guid: String
    let title: String
    let url: String
    let author: String?
    let summary: String?
    let content: String?
    let imageURL: String?
    let publishedAt: Date?
}

// MARK: - Parser

final class FeedParser: NSObject, XMLParserDelegate {

    // Feed-level
    private var feedTitle = ""
    private var feedSiteURL: String?
    private var isAtom = false

    // Item accumulation
    private var parsedItems: [ParsedItem] = []
    private var currentItem: ItemBuilder?

    // Text accumulation
    private var currentText = ""

    // MARK: - Public

    func parse(data: Data) -> ParsedFeed? {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.shouldProcessNamespaces = false
        guard xmlParser.parse() else { return nil }
        return ParsedFeed(title: feedTitle, siteURL: feedSiteURL, items: parsedItems)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentText = ""

        switch elementName {
        case "feed":
            isAtom = true
        case "item":
            currentItem = ItemBuilder()
        case "entry":
            currentItem = ItemBuilder()

        case "link":
            if isAtom {
                // Atom <link> is an empty element with attributes
                let rel = attributes["rel"] ?? "alternate"
                guard let href = attributes["href"], !href.isEmpty else { break }
                if rel == "alternate" || rel == "" {
                    if currentItem != nil {
                        if currentItem?.url == nil { currentItem?.url = href }
                    } else if feedSiteURL == nil {
                        feedSiteURL = href
                    }
                }
            }

        case "media:content", "media:thumbnail":
            guard let url = attributes["url"], currentItem?.imageURL == nil else { break }
            let medium = attributes["medium"] ?? "image"
            if medium == "image" { currentItem?.imageURL = url }

        case "enclosure":
            guard let url = attributes["url"],
                  let type_ = attributes["type"],
                  type_.hasPrefix("image/"),
                  currentItem?.imageURL == nil else { break }
            currentItem?.imageURL = url

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let inItem = currentItem != nil

        if isAtom {
            handleAtom(element: elementName, text: text, inEntry: inItem)
        } else {
            handleRSS(element: elementName, text: text, inItem: inItem)
        }

        if elementName == "item" || elementName == "entry" {
            if let item = currentItem?.build() {
                parsedItems.append(item)
            }
            currentItem = nil
        }

        currentText = ""
    }

    // MARK: - Format handlers

    private func handleRSS(element: String, text: String, inItem: Bool) {
        if inItem {
            switch element {
            case "title":       currentItem?.title = text
            case "link":        if !text.isEmpty { currentItem?.url = text }
            case "guid":        currentItem?.guid = text
            case "author", "dc:creator": currentItem?.author = text
            case "description":
                let plain = htmlToPlainText(text)
                currentItem?.summaryHTML = text
                currentItem?.summary = plain.truncated(to: 300)
            case "content:encoded":
                currentItem?.content = text
                let plain = htmlToPlainText(text)
                // Use content for summary if richer than description
                if plain.count > (currentItem?.summary?.count ?? 0) {
                    currentItem?.summary = plain.truncated(to: 300)
                }
            case "pubDate":     currentItem?.publishedAt = parseRFC2822(text)
            case "dc:date":     currentItem?.publishedAt = parseISO8601(text)
            default: break
            }
        } else {
            switch element {
            case "title": if feedTitle.isEmpty { feedTitle = text }
            case "link":  if feedSiteURL == nil, !text.isEmpty { feedSiteURL = text }
            default: break
            }
        }
    }

    private func handleAtom(element: String, text: String, inEntry: Bool) {
        if inEntry {
            switch element {
            case "title":       currentItem?.title = text
            case "id":          if currentItem?.guid == nil { currentItem?.guid = text }
            case "name":        currentItem?.author = text  // inside <author><name>
            case "summary":
                let plain = htmlToPlainText(text)
                currentItem?.summary = plain.truncated(to: 300)
            case "content":
                currentItem?.content = text
                let plain = htmlToPlainText(text)
                if plain.count > (currentItem?.summary?.count ?? 0) {
                    currentItem?.summary = plain.truncated(to: 300)
                }
            case "published":   currentItem?.publishedAt = parseISO8601(text)
            case "updated":     if currentItem?.publishedAt == nil { currentItem?.publishedAt = parseISO8601(text) }
            default: break
            }
        } else {
            switch element {
            case "title": if feedTitle.isEmpty { feedTitle = text }
            default: break
            }
        }
    }

    // MARK: - Helpers

    private func htmlToPlainText(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        s = s
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8230;", with: "…")
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let rfc2822Formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseRFC2822(_ string: String) -> Date? {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "dd MMM yyyy HH:mm:ss Z",
        ]
        let f = Self.rfc2822Formatter
        for format in formats {
            f.dateFormat = format
            if let date = f.date(from: string) { return date }
        }
        return nil
    }

    private func parseISO8601(_ string: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: string) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: string)
    }
}

// MARK: - Item builder

private class ItemBuilder {
    var guid: String?
    var title: String?
    var url: String?
    var author: String?
    var summary: String?
    var summaryHTML: String?
    var content: String?
    var imageURL: String?
    var publishedAt: Date?

    func build() -> ParsedItem? {
        guard
            let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
            let url   = url?.trimmingCharacters(in: .whitespacesAndNewlines),   !url.isEmpty
        else { return nil }

        return ParsedItem(
            guid:        guid ?? url,
            title:       title,
            url:         url,
            author:      author,
            summary:     summary,
            content:     content ?? summaryHTML,
            imageURL:    imageURL,
            publishedAt: publishedAt
        )
    }
}

// MARK: - String helper

private extension String {
    func truncated(to length: Int) -> String {
        guard count > length else { return self }
        return String(prefix(length)) + "…"
    }
}
