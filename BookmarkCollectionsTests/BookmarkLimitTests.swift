import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class BookmarkLimitTests: XCTestCase {
    override func tearDown() {
        BookmarkLimit.freeBookmarkLimitOverride = nil
        super.tearDown()
    }

    func testFreeLimitOverrideLowersTheGate() {
        BookmarkLimit.freeBookmarkLimitOverride = 1

        XCTAssertEqual(BookmarkLimit.freeBookmarkLimit, 1)
        XCTAssertTrue(BookmarkLimit.canCreate(activeBookmarkCount: 0, isUnlocked: false))
        XCTAssertFalse(BookmarkLimit.canCreate(activeBookmarkCount: 1, isUnlocked: false))
    }

    func testFreeLimitFallsBackToTenWithoutAnOverride() {
        BookmarkLimit.freeBookmarkLimitOverride = nil

        XCTAssertEqual(BookmarkLimit.freeBookmarkLimit, BookmarkLimit.defaultFreeBookmarkLimit)
    }

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

    func testCapIsNotEnforcedUntilTheProductHasLoaded() {
        let oldAvailability = PurchaseAccess.isProductAvailable
        defer { PurchaseAccess.setProductAvailable(oldAvailability) }

        PurchaseAccess.setProductAvailable(false)
        XCTAssertFalse(PaywallConfiguration.isEnforced)

        PurchaseAccess.setProductAvailable(true)
        XCTAssertEqual(PaywallConfiguration.isEnforced, PaywallConfiguration.isEnabled)
    }

    func testDefaultRepositorySavesPastTenWhileTheProductIsUnavailable() throws {
        let oldAccess = PurchaseAccess.isUnlocked
        let oldAvailability = PurchaseAccess.isProductAvailable
        defer {
            PurchaseAccess.setUnlocked(oldAccess)
            PurchaseAccess.setProductAvailable(oldAvailability)
        }
        PurchaseAccess.setUnlocked(false)
        PurchaseAccess.setProductAvailable(false)

        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        for number in 0..<15 {
            _ = try repository.save(url: "https://example.com/\(number)")
        }
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 15)
    }

    func testCapReturnsForNewSavesOnlyOnceTheProductLoads() throws {
        let oldAccess = PurchaseAccess.isUnlocked
        let oldAvailability = PurchaseAccess.isProductAvailable
        defer {
            PurchaseAccess.setUnlocked(oldAccess)
            PurchaseAccess.setProductAvailable(oldAvailability)
        }
        PurchaseAccess.setUnlocked(false)
        PurchaseAccess.setProductAvailable(false)

        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        for number in 0..<12 {
            _ = try BookmarkRepository(context: context).save(url: "https://example.com/\(number)")
        }

        PurchaseAccess.setProductAvailable(true)
        let capped = BookmarkRepository(context: context)
        guard capped.paywallEnabled else { return } // Paywall switched off in this build.

        XCTAssertThrowsError(try capped.save(url: "https://example.com/new")) { error in
            XCTAssertEqual(error as? BookmarkRepository.LimitError, .limitReached)
        }
        // Everything saved while the cap was off stays, and can still be updated.
        guard case .updated = try capped.save(url: "https://example.com/11", favorite: true) else {
            return XCTFail("Saving an existing link should update it.")
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 12)
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
