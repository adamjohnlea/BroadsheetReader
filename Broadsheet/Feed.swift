import Foundation
import SwiftData

@Model
final class Feed {
    var title: String
    var url: String
    var siteURL: String?
    var faviconURL: String?
    var feedDescription: String?
    var lastFetchedAt: Date?
    var fetchError: String?
    var sortOrder: Int
    var createdAt: Date

    var group: FeedGroup?

    @Relationship(deleteRule: .cascade, inverse: \FeedItem.feed)
    var items: [FeedItem]

    init(title: String, url: String) {
        self.title = title
        self.url = url
        self.sortOrder = 0
        self.createdAt = Date()
        self.items = []
    }
}
