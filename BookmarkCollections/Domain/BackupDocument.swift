import Foundation

struct BackupDocument: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let collections: [CollectionRecord]
    let bookmarks: [BookmarkRecord]
    let snippets: [SnippetRecord]

    init(
        version: Int = currentVersion,
        exportedAt: Date,
        collections: [CollectionRecord],
        bookmarks: [BookmarkRecord],
        snippets: [SnippetRecord] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.collections = collections
        self.bookmarks = bookmarks
        self.snippets = snippets
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        collections = try container.decode([CollectionRecord].self, forKey: .collections)
        bookmarks = try container.decode([BookmarkRecord].self, forKey: .bookmarks)
        snippets = try container.decodeIfPresent([SnippetRecord].self, forKey: .snippets) ?? []
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
        let lastOpenedAt: Date?
    }

    struct SnippetRecord: Codable, Sendable {
        let id: UUID
        let title: String
        let body: String
        let sourceUrl: String?
        let isFavorite: Bool
        let collectionID: UUID?
        let createdAt: Date
        let modifiedAt: Date
        let deletedAt: Date?
        let lastOpenedAt: Date?
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

