import Foundation
import SwiftData

@MainActor
struct CollectionRepository {
    let context: ModelContext

    func create(name: String) throws -> BookmarkCollection {
        let collections = try orderedCollections()
        let collection = BookmarkCollection(name: name, sortPosition: collections.count)
        context.insert(collection)
        try context.save()
        return collection
    }

    func rename(_ collection: BookmarkCollection, to name: String) throws {
        collection.name = name
        collection.modifiedAt = Date()
        try context.save()
    }

    func move(_ collection: BookmarkCollection, to destinationIndex: Int) throws {
        var collections = try orderedCollections()
        guard let sourceIndex = collections.firstIndex(where: { $0.id == collection.id }) else {
            return
        }
        let moved = collections.remove(at: sourceIndex)
        let targetIndex = min(max(destinationIndex, 0), collections.count)
        collections.insert(moved, at: targetIndex)
        normalizePositions(in: collections, modifiedAt: Date())
        try context.save()
    }

    func delete(_ collection: BookmarkCollection) throws {
        let now = Date()
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        for bookmark in bookmarks where bookmark.collection?.id == collection.id {
            bookmark.collection = nil
            bookmark.modifiedAt = now
        }
        context.delete(collection)

        let remaining = try orderedCollections().filter { $0.id != collection.id }
        normalizePositions(in: remaining, modifiedAt: now)
        try context.save()
    }

    private func orderedCollections() throws -> [BookmarkCollection] {
        try context.fetch(
            FetchDescriptor(sortBy: [
                SortDescriptor(\BookmarkCollection.sortPosition),
                SortDescriptor(\BookmarkCollection.id)
            ])
        )
    }

    private func normalizePositions(in collections: [BookmarkCollection], modifiedAt: Date) {
        for (position, collection) in collections.enumerated() {
            if collection.sortPosition != position {
                collection.sortPosition = position
                collection.modifiedAt = modifiedAt
            }
        }
    }
}

