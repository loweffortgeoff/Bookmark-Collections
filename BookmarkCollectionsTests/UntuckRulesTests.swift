import Foundation
import XCTest
@testable import BookmarkCollections

final class UntuckRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var threshold: TimeInterval { UntuckRules.forgottenAge }

    func testIsForgottenRequiresNilOpenOldEnoughAndNotDeleted() {
        let forgotten = makeBookmark(createdAt: now.addingTimeInterval(-(threshold + 1)))
        XCTAssertTrue(UntuckRules.isForgotten(forgotten, now: now))

        let young = makeBookmark(createdAt: now.addingTimeInterval(-(threshold - 1)))
        XCTAssertFalse(UntuckRules.isForgotten(young, now: now))

        let opened = makeBookmark(createdAt: now.addingTimeInterval(-(threshold + 1)))
        opened.lastOpenedAt = now.addingTimeInterval(-100)
        XCTAssertFalse(UntuckRules.isForgotten(opened, now: now))

        let deleted = makeBookmark(createdAt: now.addingTimeInterval(-(threshold + 1)))
        deleted.deletedAt = now
        XCTAssertFalse(UntuckRules.isForgotten(deleted, now: now))
    }

    func testIsForgottenBoundaryAtExactlyThreshold() {
        let atBoundary = makeBookmark(createdAt: now.addingTimeInterval(-threshold))
        XCTAssertTrue(UntuckRules.isForgotten(atBoundary, now: now))
    }

    func testSurpriseCandidatesMatchDestinationAndSearch() {
        // Wall-clock dates: `.forgotten.includes` calls `isForgotten` without an
        // injected `now`, so fixtures must be relative to `Date()`.
        let wallNow = Date()
        let old = makeBookmark(path: "old", createdAt: wallNow.addingTimeInterval(-(threshold + 10)))
        let favorite = makeBookmark(path: "fav", favorite: true, createdAt: wallNow)
        favorite.title = "Swift Guide"
        let deleted = makeBookmark(path: "gone", createdAt: wallNow)
        deleted.deletedAt = wallNow

        let all = [old, favorite, deleted]
        let forgotten = UntuckRules.surpriseCandidates(
            in: all, destination: .forgotten, searchText: ""
        )
        XCTAssertEqual(forgotten.map(\.id), [old.id])

        let searched = UntuckRules.surpriseCandidates(
            in: all, destination: .allItems, searchText: "swift"
        )
        XCTAssertEqual(searched.map(\.id), [favorite.id])

        let empty = UntuckRules.surpriseCandidates(
            in: all, destination: .recentlyDeleted, searchText: "nope"
        )
        XCTAssertTrue(empty.isEmpty)

        XCTAssertTrue(UntuckRules.hasSurpriseCandidates(in: all, destination: .forgotten, searchText: ""))
        XCTAssertTrue(UntuckRules.hasSurpriseCandidates(in: all, destination: .allItems, searchText: "swift"))
        XCTAssertFalse(UntuckRules.hasSurpriseCandidates(in: all, destination: .recentlyDeleted, searchText: "nope"))
    }

    private func makeBookmark(
        path: String = "item",
        favorite: Bool = false,
        createdAt: Date
    ) -> Bookmark {
        let bookmark = Bookmark(
            urlString: "https://example.com/\(path)",
            normalizedURLString: "https://example.com/\(path)",
            createdAt: createdAt
        )
        bookmark.isFavorite = favorite
        return bookmark
    }
}
