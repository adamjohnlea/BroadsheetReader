import Foundation

/// Full-text search matching used by the article list.
///
/// An item matches when the query appears, case-insensitively, in its title, summary,
/// content, feed name, or in the text or note of any of its highlights.
enum SearchFilter {

    /// Returns whether an article matches a search query.
    ///
    /// - Parameters:
    ///   - item: The article to test.
    ///   - query: The user's search text. Matching is case-insensitive.
    /// - Returns: `true` if any searchable field contains the query.
    static func matches(_ item: FeedItem, query: String) -> Bool {
        let q = query.lowercased()
        return item.title.lowercased().contains(q)
            || (item.summary?.lowercased().contains(q) ?? false)
            || (item.content?.lowercased().contains(q) ?? false)
            || (item.feed?.title.lowercased().contains(q) ?? false)
            || (item.bookmark?.highlights ?? []).contains { h in
                h.selectedText.lowercased().contains(q)
                || (h.note?.lowercased().contains(q) ?? false)
            }
    }
}
