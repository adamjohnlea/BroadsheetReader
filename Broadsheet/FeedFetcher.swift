import Foundation
import SwiftData

// MARK: - Errors

enum FetchError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case noFeedFound
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:    return "That doesn't look like a valid URL."
        case .httpError(let code): return "The server returned an error (\(code))."
        case .noFeedFound:   return "No RSS or Atom feed was found at that address."
        case .parseFailed:   return "The feed couldn't be parsed. Make sure the URL points to an RSS or Atom feed."
        }
    }
}

// MARK: - FeedFetcher

struct FeedFetcher {

    static let shared = FeedFetcher()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = ["User-Agent": "Broadsheet RSS Reader/1.0"]
        return URLSession(configuration: config)
    }()

    // MARK: - Network

    /// Resolves a user-supplied URL to an actual RSS/Atom feed URL.
    /// If the URL serves HTML, autodiscovers the feed from <link rel="alternate">.
    func discoverFeedURL(from urlString: String) async throws -> URL {
        guard let url = upgradedToHTTPS(urlString) else { throw FetchError.invalidURL }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.httpError(http.statusCode)
        }

        let contentType = (response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Type") ?? ""

        // Already an XML/RSS/Atom response
        if contentType.contains("xml") || contentType.contains("rss") || contentType.contains("atom") {
            return url
        }

        // HTML page — look for <link rel="alternate" type="application/rss+xml">
        if contentType.contains("html") {
            if let discovered = autodiscoverFeed(in: data, baseURL: url) {
                return discovered
            }
            throw FetchError.noFeedFound
        }

        // Optimistically try to parse as XML
        return url
    }

    private func upgradedToHTTPS(_ urlString: String) -> URL? {
        guard var components = URLComponents(string: urlString) else { return nil }
        if components.scheme == "http" { components.scheme = "https" }
        return components.url
    }

    /// Fetches and parses a feed URL, returning structured data.
    func fetchFeed(url: URL) async throws -> ParsedFeed {
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FetchError.httpError(http.statusCode)
        }

        guard let parsed = FeedParser().parse(data: data) else {
            throw FetchError.parseFailed
        }
        return parsed
    }

    // MARK: - Model operations (must be called on MainActor / from SwiftUI)

    /// Full add-feed pipeline: discover → fetch → persist. Returns the new Feed object.
    @MainActor
    func addFeed(urlString: String, group: FeedGroup? = nil, context: ModelContext) async throws -> Feed {
        let feedURL  = try await discoverFeedURL(from: urlString)
        let parsed   = try await fetchFeed(url: feedURL)

        let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let feed  = Feed(title: title.isEmpty ? feedURL.host() ?? urlString : title,
                         url: feedURL.absoluteString)
        feed.siteURL    = parsed.siteURL
        feed.faviconURL = faviconURL(for: parsed.siteURL ?? feedURL.absoluteString)
        feed.group      = group
        feed.lastFetchedAt = Date()
        context.insert(feed)

        insertNewItems(parsed.items, into: feed, context: context)
        return feed
    }

    /// Refreshes an existing feed — fetches and inserts any new items.
    @MainActor
    func refresh(_ feed: Feed, context: ModelContext) async {
        guard let url = upgradedToHTTPS(feed.url) else { return }
        do {
            let parsed = try await fetchFeed(url: url)
            feed.lastFetchedAt = Date()
            feed.fetchError    = nil
            // Persist upgraded https:// URL so stored value is never http://
            if feed.url != url.absoluteString { feed.url = url.absoluteString }
            // Update title only if it was never set properly
            if feed.title == feed.url {
                let t = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { feed.title = t }
            }
            insertNewItems(parsed.items, into: feed, context: context)
        } catch {
            feed.fetchError = error.localizedDescription
        }
    }

    /// Refreshes every feed in parallel.
    @MainActor
    func refreshAll(feeds: [Feed], context: ModelContext) async {
        await withTaskGroup(of: Void.self) { group in
            for feed in feeds {
                group.addTask { await refresh(feed, context: context) }
            }
        }
    }

    // MARK: - Private

    @MainActor
    private func insertNewItems(_ items: [ParsedItem], into feed: Feed, context: ModelContext) {
        let existingGUIDs = Set((feed.items ?? []).map(\.guid))
        for parsed in items {
            guard !existingGUIDs.contains(parsed.guid) else { continue }
            let item = FeedItem(guid: parsed.guid, title: parsed.title, url: parsed.url)
            item.author      = parsed.author
            item.summary     = parsed.summary
            item.content     = parsed.content
            item.imageURL    = parsed.imageURL
            item.publishedAt = parsed.publishedAt
            item.feed        = feed
            context.insert(item)
        }
    }

    private func autodiscoverFeed(in data: Data, baseURL: URL) -> URL? {
        guard let html = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1) else { return nil }

        // Match both attribute orderings: type before href, and href before type
        let patterns = [
            #"<link[^>]+type="application/(rss|atom)\+xml"[^>]+href="([^"]+)""#,
            #"<link[^>]+href="([^"]+)"[^>]+type="application/(rss|atom)\+xml""#,
        ]

        for pattern in patterns {
            guard let matchRange = html.range(of: pattern, options: .regularExpression) else { continue }
            let tag = String(html[matchRange])
            // Extract href value
            if let hrefRange = tag.range(of: #"href="([^"]+)""#, options: .regularExpression) {
                let hrefAttr = String(tag[hrefRange])
                    .replacingOccurrences(of: "href=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                if let url = URL(string: hrefAttr, relativeTo: baseURL)?.absoluteURL,
                   url.scheme == "http" || url.scheme == "https" {
                    return url
                }
            }
        }
        return nil
    }

    private func faviconURL(for siteURLString: String) -> String? {
        guard let url = URL(string: siteURLString),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme   = "https"   // always HTTPS — ATS blocks http:// image loads
        components.path     = "/favicon.ico"
        components.query    = nil
        components.fragment = nil
        return components.url?.absoluteString
    }
}
