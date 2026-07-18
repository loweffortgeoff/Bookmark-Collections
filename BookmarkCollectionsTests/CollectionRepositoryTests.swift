import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class CollectionRepositoryTests: XCTestCase {
    func testCreateRenameAndReorderCollections() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = CollectionRepository(context: container.mainContext)
        let first = try repository.create(name: "First")
        let second = try repository.create(name: "Second")
        let third = try repository.create(name: "Third")
        let previousModifiedAt = first.modifiedAt

        try repository.rename(first, to: "Renamed")
        try repository.move(third, to: 0)

        let collections = try orderedCollections(in: container)
        XCTAssertEqual(first.name, "Renamed")
        XCTAssertGreaterThanOrEqual(first.modifiedAt, previousModifiedAt)
        XCTAssertEqual(collections.map(\.id), [third.id, first.id, second.id])
        XCTAssertEqual(collections.map(\.sortPosition), [0, 1, 2])
    }

    func testDeletingCollectionLeavesBookmarksUnfiledAndNormalizesOrder() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = CollectionRepository(context: container.mainContext)
        let deletedCollection = try repository.create(name: "Delete Me")
        let remainingCollection = try repository.create(name: "Keep Me")
        let bookmark = Bookmark(
            urlString: "https://example.com",
            normalizedURLString: "https://example.com/"
        )
        bookmark.collection = deletedCollection
        container.mainContext.insert(bookmark)
        try container.mainContext.save()

        try repository.delete(deletedCollection)

        XCTAssertNil(bookmark.collection)
        let collections = try orderedCollections(in: container)
        XCTAssertEqual(collections.map(\.id), [remainingCollection.id])
        XCTAssertEqual(collections.map(\.sortPosition), [0])
    }

    func testFavoriteStateSurvivesMovingBetweenCollections() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collectionRepository = CollectionRepository(context: container.mainContext)
        let bookmarkRepository = BookmarkRepository(context: container.mainContext)
        let first = try collectionRepository.create(name: "First")
        let second = try collectionRepository.create(name: "Second")
        let bookmark = try createdBookmark(
            from: bookmarkRepository.save(
                url: "https://example.com/favorite",
                collection: first,
                favorite: true
            )
        )

        try bookmarkRepository.move(bookmark, to: second)

        XCTAssertEqual(bookmark.collection?.id, second.id)
        XCTAssertTrue(bookmark.isFavorite)
    }

    private func orderedCollections(in container: ModelContainer) throws -> [BookmarkCollection] {
        try container.mainContext.fetch(
            FetchDescriptor(sortBy: [SortDescriptor(\BookmarkCollection.sortPosition)])
        )
    }

    private func createdBookmark(from result: SaveResult) throws -> Bookmark {
        guard case let .created(bookmark) = result else {
            throw TestError.unexpectedSaveResult
        }
        return bookmark
    }

    private enum TestError: Error {
        case unexpectedSaveResult
    }
}

