import Foundation

/// Shared retention filtering logic used by both the sidebar counts and the article list.
/// An item is visible if:
/// - It is not hidden and not user-deleted
/// - It is bookmarked (bookmarks are exempt from retention), OR
/// - It falls within the retention window (or retention is set to "forever")
enum RetentionFilter {

    /// Filters an array of FeedItems to only those visible under the given retention setting.
    static func visibleItems(_ items: [FeedItem], retentionDays: Int) -> [FeedItem] {
        let cutoff: Date? = retentionDays > 0
            ? Date().addingTimeInterval(-Double(retentionDays) * 86400)
            : nil

        return items.filter { item in
            guard !item.isHidden && !item.userDeleted else { return false }
            // Bookmarked items are always visible regardless of retention
            guard item.bookmark == nil, let cutoff else { return true }
            return (item.publishedAt ?? item.createdAt) >= cutoff
        }
    }
}
