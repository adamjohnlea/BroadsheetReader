import Foundation
import SwiftData

@Model
final class FeedItem {
    // @Attribute(.unique) is not supported with CloudKit sync; deduplication
    // is handled in FeedFetcher.insertNewItems via an existingGUIDs check.
    var guid: String = ""
    var title: String = ""
    var url: String = ""
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedAt: Date?
    var isRead: Bool = false
    // isHidden: legacy pruning flag (set by old pruneOldItems). No longer written to.
    // Kept so previously-pruned items stay hidden after migration.
    var isHidden: Bool = false
    // userDeleted: set when the user explicitly chooses "Delete Article".
    // Note: cannot use "isDeleted" — that name is reserved by NSManagedObject (Core Data).
    var userDeleted: Bool = false
    var createdAt: Date = Date()

    var feed: Feed?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.item)
    var bookmark: Bookmark?

    init(guid: String, title: String, url: String) {
        self.guid = guid
        self.title = title
        self.url = url
    }
}
