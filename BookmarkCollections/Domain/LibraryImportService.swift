import Foundation
import SwiftData

@MainActor
struct LibraryImportService {
    let context: ModelContext

    func importText(_ text: String) throws -> ImportSummary {
        let repository = BookmarkRepository(context: context)
        var summary = ImportSummary()

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            do {
                switch try repository.save(url: line) {
                case .created:
                    summary.newCount += 1
                case .updated:
                    summary.duplicateCount += 1
                case .restored:
                    summary.restoredCount += 1
                }
            } catch {
                summary.failedLines.append(line)
            }
        }

        return summary
    }

    func importJSON(_ data: Data) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: data)
        guard document.version <= BackupDocument.currentVersion else {
            throw BackupDocument.Error.unsupportedVersion(document.version)
        }

        var summary = ImportSummary()
        let existingCollections = try context.fetch(FetchDescriptor<BookmarkCollection>())
        var collectionsByID = Dictionary(uniqueKeysWithValues: existingCollections.map { ($0.id, $0) })

        for record in document.collections {
            let collection: BookmarkCollection
            if let existing = collectionsByID[record.id] {
                collection = existing
            } else {
                collection = BookmarkCollection(
                    id: record.id,
                    name: record.name,
                    sortPosition: record.sortPosition,
                    createdAt: record.createdAt,
                    modifiedAt: record.modifiedAt
                )
                context.insert(collection)
                collectionsByID[record.id] = collection
            }
            collection.name = record.name
            collection.sortPosition = record.sortPosition
            collection.createdAt = record.createdAt
            collection.modifiedAt = record.modifiedAt
        }

        let existingBookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        var bookmarksByID = Dictionary(uniqueKeysWithValues: existingBookmarks.map { ($0.id, $0) })
        var bookmarksByNormalizedURL = Dictionary(
            grouping: existingBookmarks,
            by: \Bookmark.normalizedURLString
        )

        for record in document.bookmarks {
            let normalized: NormalizedURL
            do {
                normalized = try NormalizedURL(record.urlString)
            } catch {
                summary.failedLines.append(record.urlString)
                continue
            }

            let bookmark: Bookmark
            if let existing = bookmarksByID[record.id] {
                bookmark = existing
                if existing.deletedAt != nil && record.deletedAt == nil {
                    summary.restoredCount += 1
                } else {
                    summary.duplicateCount += 1
                }
            } else {
                bookmark = Bookmark(
                    id: record.id,
                    urlString: record.urlString,
                    normalizedURLString: normalized.string,
                    createdAt: record.createdAt,
                    modifiedAt: record.modifiedAt
                )
                context.insert(bookmark)
                bookmarksByID[record.id] = bookmark
                if bookmarksByNormalizedURL[normalized.string]?.isEmpty == false {
                    summary.duplicateCount += 1
                } else {
                    summary.newCount += 1
                }
                bookmarksByNormalizedURL[normalized.string, default: []].append(bookmark)
            }

            bookmark.urlString = record.urlString
            bookmark.normalizedURLString = normalized.string
            bookmark.title = record.title
            bookmark.domain = record.domain
            bookmark.isFavorite = record.isFavorite
            bookmark.collection = record.collectionID.flatMap { collectionsByID[$0] }
            bookmark.createdAt = record.createdAt
            bookmark.modifiedAt = record.modifiedAt
            bookmark.deletedAt = record.deletedAt
            bookmark.lastOpenedAt = record.lastOpenedAt
            bookmark.faviconData = nil
            bookmark.previewImageData = nil
            bookmark.metadataState = .pending
            bookmark.lastMetadataRefreshAt = nil
        }

        try context.save()
        try BookmarkRepository(context: context).reconcileDuplicates()
        return summary
    }
}

