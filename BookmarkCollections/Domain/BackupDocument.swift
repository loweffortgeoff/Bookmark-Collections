import Foundation

struct BackupDocument: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let collections: [CollectionRecord]
    let bookmarks: [BookmarkRecord]

    init(
        version: Int = currentVersion,
        exportedAt: Date,
        collections: [CollectionRecord],
        bookmarks: [BookmarkRecord]
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.collections = collections
        self.bookmarks = bookmarks
    }

    struct CollectionRecord: Codable, Sendable {
        let id: UUID
        let name: String
        let sortPosition: Int
        let createdAt: Date
        let modifiedAt: Date
    }

    struct BookmarkRecord: Codable, Sendable {
        let id: UUID
        let urlString: String
        let normalizedURLString: String
        let title: String
        let domain: String
        let isFavorite: Bool
        let collectionID: UUID?
        let createdAt: Date
        let modifiedAt: Date
        let deletedAt: Date?
    }

    enum Error: Swift.Error, Equatable {
        case unsupportedVersion(Int)
    }
}

struct ImportSummary: Equatable, Sendable {
    var newCount = 0
    var duplicateCount = 0
    var restoredCount = 0
    var failedLines: [String] = []
}

