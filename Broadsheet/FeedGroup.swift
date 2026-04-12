import Foundation
import SwiftData

@Model
final class FeedGroup {
    var name: String
    var sortOrder: Int
    var isCollapsed: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Feed.group)
    var feeds: [Feed]

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
        self.isCollapsed = false
        self.createdAt = Date()
        self.feeds = []
    }
}
