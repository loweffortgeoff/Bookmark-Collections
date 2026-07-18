import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class RecentlyDeletedTests: XCTestCase {
    func testSoftDeleteAndRestorePreserveTheBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let bookmark = try createdBookmark(from: repository.save(url: "https://example.com/item"))
        let deletionDate = Date(timeIntervalSince1970: 1_000)

        try repository.softDelete(bookmark, at: deletionDate)
        XCTAssertEqual(bookmark.deletedAt, deletionDate)

        try repository.restore(bookmark)
        XCTAssertNil(bookmark.deletedAt)
        XCTAssertEqual(try allBookmarks(in: container).count, 1)
    }

    func testPermanentDeleteRemovesTheBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let bookmark = try createdBookmark(from: repository.save(url: "https://example.com/item"))

        try repository.permanentlyDelete(bookmark)

        XCTAssertTrue(try allBookmarks(in: container).isEmpty)
    }

    func testPurgeRemovesOnlyItemsOlderThanThirtyDays() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let now = Date(timeIntervalSince1970: 4_000_000)
        let expired = Bookmark(urlString: "https://example.com/expired", normalizedURLString: "https://example.com/expired")
        expired.deletedAt = now.addingTimeInterval(-31 * 24 * 60 * 60)
        let boundary = Bookmark(urlString: "https://example.com/boundary", normalizedURLString: "https://example.com/boundary")
        boundary.deletedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let active = Bookmark(urlString: "https://example.com/active", normalizedURLString: "https://example.com/active")
        container.mainContext.insert(expired)
        container.mainContext.insert(boundary)
        container.mainContext.insert(active)
        try container.mainContext.save()

        let purgedCount = try repository.purgeExpiredDeleted(now: now)

        let remainingIDs = Set(try allBookmarks(in: container).map(\.id))
        XCTAssertEqual(purgedCount, 1)
        XCTAssertEqual(remainingIDs, [boundary.id, active.id])
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

