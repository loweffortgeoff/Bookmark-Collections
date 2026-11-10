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

    func testPurgeSkipsDeletedLinkWithAnActiveCopy() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let now = Date(timeIntervalSince1970: 4_000_000)
        let deletionDate = now.addingTimeInterval(-31 * 24 * 60 * 60)
        let expired = Bookmark(
            urlString: "https://example.com/shared#old",
            normalizedURLString: "https://example.com/shared",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        expired.deletedAt = deletionDate
        let active = Bookmark(
            urlString: "https://example.com/shared?utm_source=new",
            normalizedURLString: "https://example.com/shared",
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        container.mainContext.insert(expired)
        container.mainContext.insert(active)
        try container.mainContext.save()
        let expiredID = expired.id
        let activeID = active.id

        let purgedCount = try repository.purgeExpiredDeleted(now: now)

        let remaining = try allBookmarks(in: container)
        XCTAssertEqual(purgedCount, 0)
        XCTAssertEqual(Set(remaining.map(\.id)), [expiredID, activeID])
        XCTAssertEqual(remaining.first { $0.id == expiredID }?.deletedAt, deletionDate)
        XCTAssertNil(active.deletedAt)
    }

    func testPurgeRemovesExpiredNonLinksSharingAnEmptyURLWithActiveItems() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let now = Date(timeIntervalSince1970: 4_000_000)
        var activeIDs: Set<UUID> = []
        for kind in [Bookmark.Kind.image, .text] {
            let expired = Bookmark(urlString: "", normalizedURLString: "")
            expired.kind = kind
            expired.deletedAt = now.addingTimeInterval(-31 * 24 * 60 * 60)
            let active = Bookmark(urlString: "", normalizedURLString: "")
            active.kind = kind
            activeIDs.insert(active.id)
            container.mainContext.insert(expired)
            container.mainContext.insert(active)
        }
        try container.mainContext.save()

        let purgedCount = try repository.purgeExpiredDeleted(now: now)

        XCTAssertEqual(purgedCount, 2)
        XCTAssertEqual(Set(try allBookmarks(in: container).map(\.id)), activeIDs)
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

