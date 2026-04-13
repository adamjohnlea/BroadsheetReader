import Foundation
import SwiftData

@Model
final class Bookmark {
    var note: String?
    var createdAt: Date = Date()

    var item: FeedItem?

    init(item: FeedItem, note: String? = nil) {
        self.item = item
        self.note = note
    }
}
