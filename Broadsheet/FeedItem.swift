import Foundation
import SwiftData

@Model
final class FeedItem {
    @Attribute(.unique) var guid: String
    var title: String
    var url: String
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: String?
    var publishedAt: Date?
    var isRead: Bool
    var isHidden: Bool
    var createdAt: Date

    var feed: Feed?

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.item)
    var bookmark: Bookmark?

    init(guid: String, title: String, url: String) {
        self.guid = guid
        self.title = title
        self.url = url
        self.isRead = false
        self.isHidden = false
        self.createdAt = Date()
    }
}
