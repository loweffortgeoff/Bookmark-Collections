import Foundation
import SwiftData

@Model
final class Bookmark {
    enum MetadataState: String, Codable, CaseIterable {
        case pending
        case ready
        case failed
    }

    var id: UUID = UUID()
    var urlString: String = ""
    var normalizedURLString: String = ""
    var title: String = ""
    var domain: String = ""
    @Attribute(.externalStorage) var faviconData: Data?
    @Attribute(.externalStorage) var previewImageData: Data?
    var isFavorite: Bool = false
    var collection: BookmarkCollection?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?
    var metadataStateRawValue: String = MetadataState.pending.rawValue
    var lastMetadataRefreshAt: Date?

    var metadataState: MetadataState {
        get { MetadataState(rawValue: metadataStateRawValue) ?? .pending }
        set { metadataStateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        urlString: String,
        normalizedURLString: String,
        createdAt: Date = Date(),
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.urlString = urlString
        self.normalizedURLString = normalizedURLString
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }
}

