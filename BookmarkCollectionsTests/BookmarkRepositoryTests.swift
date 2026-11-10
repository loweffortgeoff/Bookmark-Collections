import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class BookmarkRepositoryTests: XCTestCase {
    func testSaveCreatesPendingBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let result = try repository.save(url: "https://Example.com/article#intro")

        guard case let .created(bookmark) = result else {
            return XCTFail("Expected a newly created bookmark")
        }
        XCTAssertEqual(bookmark.urlString, "https://Example.com/article#intro")
        XCTAssertEqual(bookmark.normalizedURLString, "https://example.com/article")
        XCTAssertEqual(bookmark.domain, "example.com")
        XCTAssertEqual(bookmark.metadataState, .pending)
        XCTAssertNil(bookmark.deletedAt)
    }

    func testDuplicateSaveUpdatesExistingBookmarkWithoutChangingItsID() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let first = try repository.save(url: "https://example.com/story?utm_source=feed")
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        container.mainContext.insert(collection)
        let originalID = try createdBookmark(from: first).id

        let result = try repository.save(
            url: "https://EXAMPLE.com/story",
            collection: collection,
            favorite: true
        )

        guard case let .updated(bookmark) = result else {
            return XCTFail("Expected the existing bookmark to be updated")
        }
        XCTAssertEqual(bookmark.id, originalID)
        XCTAssertEqual(bookmark.collection?.id, collection.id)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(try allBookmarks(in: container).count, 1)
    }

    func testSaveRestoresASoftDeletedMatch() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let deleted = Bookmark(
            urlString: "https://example.com/deleted",
            normalizedURLString: "https://example.com/deleted"
        )
        deleted.deletedAt = Date(timeIntervalSince1970: 100)
        container.mainContext.insert(deleted)
        try container.mainContext.save()

        let result = try repository.save(url: "https://example.com/deleted", favorite: true)

        guard case let .restored(bookmark) = result else {
            return XCTFail("Expected the deleted bookmark to be restored")
        }
        XCTAssertEqual(bookmark.id, deleted.id)
        XCTAssertNil(bookmark.deletedAt)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(try allBookmarks(in: container).count, 1)
    }

    func testReconcileDuplicatesKeepsEarliestAndMergesNewestEdits() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let olderCollection = BookmarkCollection(name: "Older", sortPosition: 0)
        let newerCollection = BookmarkCollection(name: "Newer", sortPosition: 1)
        let earliest = Bookmark(
            urlString: "https://example.com/item?utm_source=one",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 100),
            modifiedAt: Date(timeIntervalSince1970: 200)
        )
        earliest.title = "Original"
        earliest.isFavorite = true
        earliest.collection = olderCollection
        let newest = Bookmark(
            urlString: "https://example.com/item",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 150),
            modifiedAt: Date(timeIntervalSince1970: 300)
        )
        newest.title = "Most Recent Edit"
        newest.collection = newerCollection
        container.mainContext.insert(olderCollection)
        container.mainContext.insert(newerCollection)
        container.mainContext.insert(earliest)
        container.mainContext.insert(newest)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        let canonical = try XCTUnwrap(bookmarks.first)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(canonical.id, earliest.id)
        XCTAssertEqual(canonical.title, "Most Recent Edit")
        XCTAssertEqual(canonical.collection?.id, newerCollection.id)
        XCTAssertTrue(canonical.isFavorite)
    }

    func testBookmarkDefaultsToLinkKindAndRoundTripsImage() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = Bookmark(urlString: "https://example.com/kind", normalizedURLString: "https://example.com/kind")
        container.mainContext.insert(bookmark)
        try container.mainContext.save()

        XCTAssertEqual(bookmark.kind, .link)

        bookmark.kind = .image
        try container.mainContext.save()
        XCTAssertEqual(bookmark.kindRawValue, Bookmark.Kind.image.rawValue)
    }

    func testSaveImageCreatesImageBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let data = Data([0x89, 0x50, 0x4E, 0x47])

        let bookmark = try repository.saveImage(data: data, title: "Screenshot", favorite: true)

        XCTAssertEqual(bookmark.kind, .image)
        XCTAssertEqual(bookmark.title, "Screenshot")
        XCTAssertEqual(bookmark.previewImageData, data)
        XCTAssertTrue(bookmark.urlString.isEmpty)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 1)
    }

    func testReconcileDuplicatesIgnoresImageBookmarks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.saveImage(data: Data([0x01]), title: "First")
        _ = try repository.saveImage(data: Data([0x02]), title: "Second")

        try repository.reconcileDuplicates()

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 2)
    }

    func testMarkOpenedSetsLastOpenedAtAndPreservesModifiedAt() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let bookmark = try createdBookmark(from: repository.save(url: "https://example.com/open-me"))
        let originalModified = bookmark.modifiedAt
        let openedAt = originalModified.addingTimeInterval(1)

        try repository.markOpened(bookmark, at: openedAt)

        XCTAssertEqual(bookmark.lastOpenedAt, openedAt)
        XCTAssertEqual(bookmark.modifiedAt, originalModified)
    }

    func testReconcileDuplicatesKeepsLaterLastOpenedAt() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let earlierOpen = Date(timeIntervalSince1970: 200)
        let laterOpen = Date(timeIntervalSince1970: 400)

        let earliest = Bookmark(
            urlString: "https://example.com/item",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 100),
            modifiedAt: Date(timeIntervalSince1970: 100)
        )
        earliest.lastOpenedAt = earlierOpen
        let newest = Bookmark(
            urlString: "https://example.com/item",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 150),
            modifiedAt: Date(timeIntervalSince1970: 300)
        )
        newest.lastOpenedAt = laterOpen
        container.mainContext.insert(earliest)
        container.mainContext.insert(newest)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.lastOpenedAt, laterOpen)
    }

    func testReconcileDuplicatesPrefersNonNilLastOpenedAt() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let openDate = Date(timeIntervalSince1970: 250)

        let earliest = Bookmark(
            urlString: "https://example.com/item",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 100),
            modifiedAt: Date(timeIntervalSince1970: 100)
        )
        // lastOpenedAt remains nil
        let newest = Bookmark(
            urlString: "https://example.com/item",
            normalizedURLString: "https://example.com/item",
            createdAt: Date(timeIntervalSince1970: 150),
            modifiedAt: Date(timeIntervalSince1970: 300)
        )
        newest.lastOpenedAt = openDate
        container.mainContext.insert(earliest)
        container.mainContext.insert(newest)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        XCTAssertEqual(try allBookmarks(in: container).first?.lastOpenedAt, openDate)
    }

    func testReconcileLeavesAllDeletedGroupDeleted() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let url = "https://example.com/item"
        let earliest = Bookmark(urlString: url, normalizedURLString: url,
                                createdAt: Date(timeIntervalSince1970: 100))
        earliest.deletedAt = Date(timeIntervalSince1970: 150)
        let later = Bookmark(urlString: url, normalizedURLString: url,
                             createdAt: Date(timeIntervalSince1970: 200))
        later.deletedAt = Date(timeIntervalSince1970: 250)
        container.mainContext.insert(earliest)
        container.mainContext.insert(later)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.id, earliest.id)
        XCTAssertNotNil(bookmarks.first?.deletedAt)
    }

    func testReconcileRevivesEarliestWhenALaterCopyIsActive() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let url = "https://example.com/item"
        let earliest = Bookmark(urlString: url, normalizedURLString: url,
                                createdAt: Date(timeIntervalSince1970: 100))
        earliest.deletedAt = Date(timeIntervalSince1970: 150)
        let later = Bookmark(urlString: url, normalizedURLString: url,
                             createdAt: Date(timeIntervalSince1970: 200))
        container.mainContext.insert(earliest)
        container.mainContext.insert(later)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertNil(bookmarks.first?.deletedAt)
        XCTAssertEqual(bookmarks.first?.id, earliest.id)
    }

    func testReconcileLeavesExactClonesUntouched() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let url = "https://example.com/item"
        let id = UUID()
        let created = Date(timeIntervalSince1970: 100)
        container.mainContext.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
        container.mainContext.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        XCTAssertEqual(try allBookmarks(in: container).count, 2)
    }

    func testReconcileLeavesCloneOnlyDifferingTitlesUnmergedAndDoesNotSave() throws {
        for reversed in [false, true] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            let url = "https://example.com/item"
            let id = UUID()
            let created = Date(timeIntervalSince1970: 100)
            let first = Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created)
            first.title = "First title"
            let second = Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created,
                                  modifiedAt: Date(timeIntervalSince1970: 200))
            second.title = "Edited clone title"
            for clone in reversed ? [second, first] : [first, second] {
                context.insert(clone)
            }
            let collection = BookmarkCollection(name: "Saved name", sortPosition: 0)
            context.insert(collection)
            try context.save()
            collection.name = "Unsaved name"
            XCTAssertTrue(context.hasChanges)

            try BookmarkRepository(context: context).reconcileDuplicates()

            XCTAssertEqual(try allBookmarks(in: container).count, 2)
            XCTAssertEqual(first.title, "First title")
            XCTAssertEqual(second.title, "Edited clone title")
            XCTAssertEqual(first.modifiedAt, created)
            XCTAssertEqual(second.modifiedAt, Date(timeIntervalSince1970: 200))
            XCTAssertTrue(context.hasChanges, "Clone-only cleanup must not save unrelated pending edits")
            let storedCollections = try ModelContext(container).fetch(FetchDescriptor<BookmarkCollection>())
            XCTAssertEqual(storedCollections.first?.name, "Saved name")
        }
    }

    func testReconcileStillMergesClonesWithADistinctThirdRecord() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let url = "https://example.com/item"
        let id = UUID()
        let created = Date(timeIntervalSince1970: 100)
        container.mainContext.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
        container.mainContext.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        container.mainContext.insert(collection)
        let newest = Date(timeIntervalSince1970: 300)
        let other = Bookmark(urlString: url, normalizedURLString: url,
                             createdAt: Date(timeIntervalSince1970: 200), modifiedAt: newest)
        other.isFavorite = true
        other.title = "Newest"
        other.collection = collection
        container.mainContext.insert(other)
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertFalse(bookmarks.contains { $0.id == other.id })
        XCTAssertTrue(bookmarks.allSatisfy(\.isFavorite))
        XCTAssertTrue(bookmarks.allSatisfy { $0.title == "Newest" })
        XCTAssertTrue(bookmarks.allSatisfy { $0.collection?.id == collection.id })
        XCTAssertTrue(bookmarks.allSatisfy { $0.modifiedAt == newest })
    }

    func testReconcileLeavesADeletedCloneDeleted() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let url = "https://example.com/item"
        let id = UUID()
        let created = Date(timeIntervalSince1970: 100)
        let deleted = Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created)
        deleted.deletedAt = Date(timeIntervalSince1970: 150)
        container.mainContext.insert(deleted)
        container.mainContext.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
        try container.mainContext.save()

        try repository.reconcileDuplicates()

        let bookmarks = try allBookmarks(in: container)
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertEqual(bookmarks.filter { $0.deletedAt != nil }.count, 1)
    }

    func testReconcileRevivesSurvivorsOnlyWhenNoneIsActive() throws {
        let url = "https://example.com/item"
        let created = Date(timeIntervalSince1970: 100)
        let deletedAt = Date(timeIntervalSince1970: 150)

        // Both clones deleted, a distinct later copy active: the survivors revive.
        let reviveContainer = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let reviveID = UUID()
        for _ in 0..<2 {
            let clone = Bookmark(id: reviveID, urlString: url, normalizedURLString: url, createdAt: created)
            clone.deletedAt = deletedAt
            reviveContainer.mainContext.insert(clone)
        }
        reviveContainer.mainContext.insert(Bookmark(
            urlString: url, normalizedURLString: url, createdAt: Date(timeIntervalSince1970: 200)
        ))
        try reviveContainer.mainContext.save()

        try BookmarkRepository(context: reviveContainer.mainContext).reconcileDuplicates()

        let revived = try allBookmarks(in: reviveContainer)
        XCTAssertEqual(revived.count, 2)
        XCTAssertTrue(revived.allSatisfy { $0.deletedAt == nil })

        // One clone already active: the deleted clone stays deleted.
        let keepContainer = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let keepID = UUID()
        keepContainer.mainContext.insert(Bookmark(id: keepID, urlString: url, normalizedURLString: url, createdAt: created))
        let deletedClone = Bookmark(id: keepID, urlString: url, normalizedURLString: url, createdAt: created)
        deletedClone.deletedAt = deletedAt
        keepContainer.mainContext.insert(deletedClone)
        keepContainer.mainContext.insert(Bookmark(
            urlString: url, normalizedURLString: url, createdAt: Date(timeIntervalSince1970: 200)
        ))
        try keepContainer.mainContext.save()

        try BookmarkRepository(context: keepContainer.mainContext).reconcileDuplicates()

        let kept = try allBookmarks(in: keepContainer)
        XCTAssertEqual(kept.count, 2)
        XCTAssertEqual(kept.filter { $0.deletedAt != nil }.count, 1)
    }

    func testReconcileSurvivorsDoNotDependOnInsertionOrder() throws {
        let url = "https://example.com/item"
        let id = UUID()
        let otherID = UUID()
        let created = Date(timeIntervalSince1970: 100)

        func survivors(distinctFirst: Bool) throws -> [String] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            let distinct = Bookmark(id: otherID, urlString: url, normalizedURLString: url,
                                    createdAt: Date(timeIntervalSince1970: 200))
            if distinctFirst { context.insert(distinct) }
            context.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
            context.insert(Bookmark(id: id, urlString: url, normalizedURLString: url, createdAt: created))
            if !distinctFirst { context.insert(distinct) }
            try context.save()
            try BookmarkRepository(context: context).reconcileDuplicates()
            return try allBookmarks(in: container)
                .map { "\($0.id.uuidString)@\($0.createdAt.timeIntervalSince1970)" }
                .sorted()
        }

        let forward = try survivors(distinctFirst: false)
        let reversed = try survivors(distinctFirst: true)

        XCTAssertEqual(forward.count, 2)
        XCTAssertEqual(forward, reversed)
    }

    private func createdBookmark(from result: SaveResult) throws -> Bookmark {
        guard case let .created(bookmark) = result else {
            throw TestError.unexpectedSaveResult
        }
        return bookmark
    }

    private func allBookmarks(in container: ModelContainer) throws -> [Bookmark] {
        try container.mainContext.fetch(FetchDescriptor<Bookmark>())
    }

    private enum TestError: Error {
        case unexpectedSaveResult
    }
}

