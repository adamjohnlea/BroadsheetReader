import Foundation
import SwiftData

@Model
final class FeedGroup {
    var name: String = ""
    var sortOrder: Int = 0
    var isCollapsed: Bool = false
    var createdAt: Date = Date()

    // Optional array required for CloudKit compatibility.
    @Relationship(deleteRule: .nullify, inverse: \Feed.group)
    var feeds: [Feed]?

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
}
