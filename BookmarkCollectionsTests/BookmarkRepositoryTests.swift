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

