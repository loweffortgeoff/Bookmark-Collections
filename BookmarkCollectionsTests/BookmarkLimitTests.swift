import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class BookmarkLimitTests: XCTestCase {
    func testFreeTierAllowsTenActiveBookmarks() {
        XCTAssertTrue(BookmarkLimit.canCreate(activeBookmarkCount: 10, isUnlocked: true))
        XCTAssertTrue(BookmarkLimit.canCreate(activeBookmarkCount: 9, isUnlocked: false))
    }

    func testFreeTierBlocksTheEleventhActiveBookmark() {
        XCTAssertFalse(BookmarkLimit.canCreate(activeBookmarkCount: 10, isUnlocked: false))
    }

    func testRepositoryUpdatesExistingLinkAtTheLimit() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(
            context: container.mainContext,
            isUnlocked: false,
            paywallEnabled: true
        )
        for number in 0..<10 {
            _ = try repository.save(url: "https://example.com/\(number)")
        }

        let result = try repository.save(url: "https://example.com/0", favorite: true)

        guard case let .updated(bookmark) = result else {
            return XCTFail("Saving an existing link should update it.")
        }
        XCTAssertTrue(bookmark.isFavorite)
    }

    func testRepositoryBlocksTheEleventhNewBookmark() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(
            context: container.mainContext,
            isUnlocked: false,
            paywallEnabled: true
        )
        for number in 0..<10 {
            _ = try repository.save(url: "https://example.com/\(number)")
        }

        XCTAssertThrowsError(try repository.save(url: "https://example.com/eleven")) { error in
            XCTAssertEqual(error as? BookmarkRepository.LimitError, .limitReached)
        }
    }
}
