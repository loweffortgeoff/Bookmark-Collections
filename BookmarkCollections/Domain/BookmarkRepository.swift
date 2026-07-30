import Foundation
import SwiftData

enum SaveResult {
    case created(Bookmark)
    case updated(Bookmark)
    case restored(Bookmark)
}

@MainActor
struct BookmarkRepository {
    let context: ModelContext

    func save(
        url value: String,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> SaveResult {
        let normalized = try NormalizedURL(value)
        let normalizedString = normalized.string
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.normalizedURLString == normalizedString
            },
            sortBy: [SortDescriptor(\Bookmark.createdAt)]
        )
        let matches = try context.fetch(descriptor)
        let now = Date()

        let result: SaveResult
        if let existing = matches.first(where: { $0.deletedAt == nil }) {
            existing.collection = collection
            existing.isFavorite = favorite
            existing.modifiedAt = now
            result = .updated(existing)
        } else if let deleted = matches.first {
            deleted.deletedAt = nil
            deleted.collection = collection
            deleted.isFavorite = favorite
            deleted.modifiedAt = now
            result = .restored(deleted)
        } else {
            let bookmark = Bookmark(
                urlString: value,
                normalizedURLString: normalizedString,
                createdAt: now
            )
            bookmark.domain = normalized.url.host?.lowercased() ?? ""
            bookmark.collection = collection
            bookmark.isFavorite = favorite
            bookmark.metadataState = .pending
            context.insert(bookmark)
            result = .created(bookmark)
        }

        try context.save()
        return result
    }

    @discardableResult
    func saveImage(
        data: Data,
        title: String,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> Bookmark {
        let now = Date()
        let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: now)
        bookmark.kind = .image
        bookmark.title = title
        bookmark.previewImageData = data
        bookmark.collection = collection
        bookmark.isFavorite = favorite
        bookmark.metadataState = .ready
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    func reconcileDuplicates() throws {
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            .filter { $0.kind == .link }
        let groups = Dictionary(grouping: bookmarks, by: \Bookmark.normalizedURLString)
        var changed = false

        for group in groups.values where group.count > 1 {
            let orderedByCreation = group.sorted { left, right in
                if left.createdAt == right.createdAt {
                    return left.id.uuidString < right.id.uuidString
                }
                return left.createdAt < right.createdAt
            }
            guard let canonical = orderedByCreation.first else { continue }
            let mostRecentlyModified = group.max { left, right in
                if left.modifiedAt == right.modifiedAt {
                    return left.id.uuidString < right.id.uuidString
                }
                return left.modifiedAt < right.modifiedAt
            } ?? canonical

            canonical.isFavorite = group.contains(where: \Bookmark.isFavorite)
            canonical.title = mostRecentlyModified.title
            canonical.collection = mostRecentlyModified.collection
            canonical.modifiedAt = mostRecentlyModified.modifiedAt
            canonical.lastOpenedAt = group.compactMap(\.lastOpenedAt).max()

            for duplicate in orderedByCreation.dropFirst() {
                context.delete(duplicate)
            }
            changed = true
        }

        if changed {
            try context.save()
        }
    }

    func markOpened(_ bookmark: Bookmark, at date: Date = Date()) throws {
        bookmark.lastOpenedAt = date
        bookmark.modifiedAt = date
        try context.save()
    }

    func setFavorite(_ bookmark: Bookmark, to isFavorite: Bool) throws {
        bookmark.isFavorite = isFavorite
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func move(_ bookmark: Bookmark, to collection: BookmarkCollection?) throws {
        bookmark.collection = collection
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func softDelete(_ bookmark: Bookmark, at date: Date = Date()) throws {
        bookmark.deletedAt = date
        bookmark.modifiedAt = date
        try context.save()
    }

    func restore(_ bookmark: Bookmark) throws {
        bookmark.deletedAt = nil
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func permanentlyDelete(_ bookmark: Bookmark) throws {
        context.delete(bookmark)
        try context.save()
    }

    @discardableResult
    func purgeExpiredDeleted(now: Date = Date()) throws -> Int {
        let expirationDate = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        let expired = bookmarks.filter { bookmark in
            guard let deletedAt = bookmark.deletedAt else { return false }
            return deletedAt < expirationDate
        }
        for bookmark in expired {
            context.delete(bookmark)
        }
        if !expired.isEmpty {
            try context.save()
        }
        return expired.count
    }
}
