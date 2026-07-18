import Foundation
import SwiftData

@Model
final class BookmarkCollection {
    var id: UUID = UUID()
    var name: String = ""
    var sortPosition: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    @Relationship(deleteRule: .nullify, inverse: \Bookmark.collection)
    var bookmarks: [Bookmark]?

    init(
        id: UUID = UUID(),
        name: String,
        sortPosition: Int,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortPosition = sortPosition
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.bookmarks = []
    }
}

