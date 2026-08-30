import Foundation
import SwiftData

@MainActor
struct LibraryImportService {
    let context: ModelContext

    // Backups arrive from producers that always write fractional seconds and
    // from producers that never do. `.iso8601` accepts only one of those, so
    // one unexpected date would fail the whole document. Both formatters are
    // configured once and never mutated, which `ISO8601DateFormatter` supports
    // across threads, so a backup with thousands of dates allocates neither.
    nonisolated(unsafe) private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let wholeSecondDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

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
            } catch let error as BookmarkRepository.LimitError {
                throw error
            } catch {
                summary.failedLines.append(line)
            }
        }

        return summary
    }

    func importJSON(_ data: Data) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = Self.fractionalDateFormatter.date(from: value) { return date }
            if let date = Self.wholeSecondDateFormatter.date(from: value) { return date }
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "“\(value)” is not an ISO 8601 date."
                )
            )
        }
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
        try assertCanImport(document, existingBookmarks: existingBookmarks)
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

        for record in document.snippets {
            let body = record.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }

            let existing = bookmarksByID[record.id]

            // A hand-edited or concatenated file can reuse one id for both a
            // link and a snippet. Rewriting the link in place would destroy its
            // URL, so the snippet is reported instead of applied.
            if let existing, existing.kind != .text {
                summary.failedLines.append("Snippet \(record.id) collides with an existing bookmark.")
                continue
            }

            if let existing {
                if existing.deletedAt != nil && record.deletedAt == nil {
                    summary.restoredCount += 1
                } else {
                    summary.duplicateCount += 1
                }
            } else {
                summary.newCount += 1
            }

            let snippet = existing ?? Bookmark(
                id: record.id,
                urlString: "",
                normalizedURLString: "",
                createdAt: record.createdAt,
                modifiedAt: record.modifiedAt
            )
            snippet.kind = .text
            snippet.snippetBody = body
            snippet.title = BookmarkRepository.deriveSnippetTitle(record.title, body: body)
            // Glaze writes no domain for a snippet, so the host is always
            // derived from the source link here, never read from the backup.
            BookmarkRepository.applySource(record.sourceUrl, to: snippet)
            snippet.normalizedURLString = ""
            snippet.isFavorite = record.isFavorite
            snippet.collection = record.collectionID.flatMap { collectionsByID[$0] }
            snippet.createdAt = record.createdAt
            snippet.modifiedAt = record.modifiedAt
            snippet.deletedAt = record.deletedAt
            snippet.lastOpenedAt = record.lastOpenedAt
            snippet.metadataState = .ready

            if existing == nil {
                context.insert(snippet)
                bookmarksByID[record.id] = snippet
            }
        }

        try context.save()
        try BookmarkRepository(context: context).reconcileDuplicates()
        return summary
    }

    private func assertCanImport(_ document: BackupDocument, existingBookmarks: [Bookmark]) throws {
        guard PaywallConfiguration.isEnabled, !PurchaseAccess.isUnlocked else { return }
        let activeBookmarkCount = existingBookmarks.lazy.filter { $0.deletedAt == nil }.count
        let existingBookmarksByID = Dictionary(uniqueKeysWithValues: existingBookmarks.map { ($0.id, $0) })

        let restoredOrNewLinks = document.bookmarks.reduce(into: 0) { count, record in
            guard record.deletedAt == nil else { return }
            guard let existing = existingBookmarksByID[record.id] else {
                count += 1
                return
            }
            if existing.deletedAt != nil { count += 1 }
        }
        let restoredOrNewSnippets = document.snippets.reduce(into: 0) { count, record in
            guard !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  record.deletedAt == nil else { return }
            guard let existing = existingBookmarksByID[record.id] else {
                count += 1
                return
            }
            if existing.deletedAt != nil { count += 1 }
        }
        guard BookmarkLimit.canCreate(
            activeBookmarkCount: activeBookmarkCount + restoredOrNewLinks + restoredOrNewSnippets - 1,
            isUnlocked: false
        ) else {
            throw BookmarkRepository.LimitError.limitReached
        }
    }
}
