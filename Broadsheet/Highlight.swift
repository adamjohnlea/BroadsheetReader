import Foundation
import SwiftData

@Model
final class Highlight {
    var selectedText: String = ""
    var prefixContext: String = ""   // ~20 chars before selection for re-anchoring
    var suffixContext: String = ""   // ~20 chars after selection for re-anchoring
    var note: String?
    var createdAt: Date = Date()

    // Linked to Bookmark (not FeedItem) — highlights require a bookmark
    var bookmark: Bookmark?

    init(selectedText: String, prefixContext: String = "", suffixContext: String = "", note: String? = nil, bookmark: Bookmark? = nil) {
        self.selectedText = selectedText
        self.prefixContext = prefixContext
        self.suffixContext = suffixContext
        self.note = note
        self.bookmark = bookmark
    }
}
