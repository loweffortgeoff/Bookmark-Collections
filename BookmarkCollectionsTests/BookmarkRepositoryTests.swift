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

    func testMarkOpenedSetsLastOpenedAtAndBumpsModifiedAt() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let bookmark = try createdBookmark(from: repository.save(url: "https://example.com/open-me"))
        let originalModified = bookmark.modifiedAt
        // Must be >= originalModified so the "bumps modifiedAt" assertion is meaningful.
        let openedAt = originalModified.addingTimeInterval(1)

        try repository.markOpened(bookmark, at: openedAt)

        XCTAssertEqual(bookmark.lastOpenedAt, openedAt)
        XCTAssertEqual(bookmark.modifiedAt, openedAt)
        XCTAssertGreaterThanOrEqual(bookmark.modifiedAt, originalModified)
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

