import Foundation
import SwiftData

@Model
final class Feed {
    var title: String = ""
    var url: String = ""
    var siteURL: String?
    var faviconURL: String?
    var feedDescription: String?
    var lastFetchedAt: Date?
    var fetchError: String?
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    var group: FeedGroup?

    // Optional array required for CloudKit compatibility — CloudKit requires all
    // relationships to be optional in the Core Data schema.
    @Relationship(deleteRule: .cascade, inverse: \FeedItem.feed)
    var items: [FeedItem]?

    init(title: String, url: String) {
        self.title = title
        self.url = url
    }
}
