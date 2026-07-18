import Foundation
import XCTest
@testable import BookmarkCollections

final class LibraryFilteringTests: XCTestCase {
    func testDestinationsIncludeOnlyTheirBookmarks() {
        let collection = BookmarkCollection(name: "Development", sortPosition: 0)
        let active = makeBookmark(path: "active")
        let favorite = makeBookmark(path: "favorite", favorite: true)
        let filed = makeBookmark(path: "filed", collection: collection)
        let deleted = makeBookmark(path: "deleted", deletedAt: Date())

        XCTAssertTrue(LibraryDestination.allItems.includes(active))
        XCTAssertTrue(LibraryDestination.allItems.includes(favorite))
        XCTAssertFalse(LibraryDestination.allItems.includes(deleted))
        XCTAssertTrue(LibraryDestination.favorites.includes(favorite))
        XCTAssertFalse(LibraryDestination.favorites.includes(active))
        XCTAssertTrue(LibraryDestination.collection(collection.id).includes(filed))
        XCTAssertFalse(LibraryDestination.collection(collection.id).includes(active))
        XCTAssertTrue(LibraryDestination.recentlyDeleted.includes(deleted))
        XCTAssertFalse(LibraryDestination.recentlyDeleted.includes(active))
    }

    func testSearchMatchesEverySupportedFieldCaseInsensitively() {
        let collection = BookmarkCollection(name: "Reference Material", sortPosition: 0)
        let bookmark = Bookmark(
            urlString: "https://example.com/path/to/SwiftData",
            normalizedURLString: "https://example.com/path/to/SwiftData"
        )
        bookmark.title = "Persistence Guide"
        bookmark.domain = "EXAMPLE.com"
        bookmark.collection = collection

        XCTAssertTrue(LibraryDestination.allItems.matches(bookmark, searchText: "persistence"))
        XCTAssertTrue(LibraryDestination.allItems.matches(bookmark, searchText: "example.COM"))
        XCTAssertTrue(LibraryDestination.allItems.matches(bookmark, searchText: "swiftdata"))
        XCTAssertTrue(LibraryDestination.allItems.matches(bookmark, searchText: "reference"))
        XCTAssertTrue(LibraryDestination.allItems.matches(bookmark, searchText: "  "))
        XCTAssertFalse(LibraryDestination.allItems.matches(bookmark, searchText: "photography"))
    }

    func testEverySortUsesUUIDAsAStableTieBreaker() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = makeBookmark(path: "same", id: firstID)
        let second = makeBookmark(path: "same", id: secondID)
        let date = Date(timeIntervalSince1970: 100)
        for bookmark in [first, second] {
            bookmark.title = "Same"
            bookmark.domain = "example.com"
            bookmark.createdAt = date
            bookmark.modifiedAt = date
        }

        for sort in BookmarkSort.allCases {
            let ordered = [second, first].sorted(using: sort.descriptors(ascending: true))
            XCTAssertEqual(ordered.map(\.id), [firstID, secondID], String(describing: sort))
        }
    }

    private func makeBookmark(
        path: String,
        id: UUID = UUID(),
        favorite: Bool = false,
        collection: BookmarkCollection? = nil,
        deletedAt: Date? = nil
    ) -> Bookmark {
        let bookmark = Bookmark(
            id: id,
            urlString: "https://example.com/\(path)",
            normalizedURLString: "https://example.com/\(path)"
        )
        bookmark.isFavorite = favorite
        bookmark.collection = collection
        bookmark.deletedAt = deletedAt
        return bookmark
    }
}

