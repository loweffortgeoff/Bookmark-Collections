import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ImportExportTests: XCTestCase {
    func testTextImportReportsNewDuplicateRestoredAndInvalidLines() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/existing")
        let deleted = try createdBookmark(from: repository.save(url: "https://example.com/deleted"))
        try repository.softDelete(deleted)
        let service = LibraryImportService(context: container.mainContext)

        let summary = try service.importText("""

        https://example.com/new
        https://EXAMPLE.com/existing?utm_source=list
        https://example.com/deleted
        not a URL

        """)

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(summary.duplicateCount, 1)
        XCTAssertEqual(summary.restoredCount, 1)
        XCTAssertEqual(summary.failedLines, ["not a URL"])
    }

    func testJSONRoundTripPreservesUserDataAndOrganization() throws {
        let source = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let bookmarkID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let modifiedAt = Date(timeIntervalSince1970: 2_000)
        let collection = BookmarkCollection(
            id: collectionID,
            name: "Research",
            sortPosition: 3,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
        let bookmark = Bookmark(
            id: bookmarkID,
            urlString: "https://example.com/article?id=7",
            normalizedURLString: "https://example.com/article?id=7",
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
        bookmark.title = "My Edited Title"
        bookmark.domain = "example.com"
        bookmark.isFavorite = true
        bookmark.collection = collection
        bookmark.previewImageData = Data([9, 9, 9])
        bookmark.faviconData = Data([8, 8])
        source.mainContext.insert(collection)
        source.mainContext.insert(bookmark)
        try source.mainContext.save()
        let data = try LibraryExportService(context: source.mainContext).exportJSON(
            exportedAt: Date(timeIntervalSince1970: 3_000)
        )

        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("previewImageData"))
        XCTAssertFalse(json.contains("faviconData"))

        let destination = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try LibraryImportService(context: destination.mainContext).importJSON(data)

        let restoredCollection = try XCTUnwrap(
            destination.mainContext.fetch(FetchDescriptor<BookmarkCollection>()).first
        )
        let restoredBookmark = try XCTUnwrap(
            destination.mainContext.fetch(FetchDescriptor<Bookmark>()).first
        )
        XCTAssertEqual(restoredCollection.id, collectionID)
        XCTAssertEqual(restoredCollection.name, "Research")
        XCTAssertEqual(restoredCollection.sortPosition, 3)
        XCTAssertEqual(restoredCollection.createdAt, createdAt)
        XCTAssertEqual(restoredCollection.modifiedAt, modifiedAt)
        XCTAssertEqual(restoredBookmark.id, bookmarkID)
        XCTAssertEqual(restoredBookmark.urlString, "https://example.com/article?id=7")
        XCTAssertEqual(restoredBookmark.title, "My Edited Title")
        XCTAssertTrue(restoredBookmark.isFavorite)
        XCTAssertEqual(restoredBookmark.collection?.id, collectionID)
        XCTAssertEqual(restoredBookmark.createdAt, createdAt)
        XCTAssertEqual(restoredBookmark.modifiedAt, modifiedAt)
        XCTAssertEqual(restoredBookmark.metadataState, .pending)
        XCTAssertNil(restoredBookmark.previewImageData)
    }

    func testHTMLExportEscapesValuesAndDoesNotDuplicateFavorites() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collection = BookmarkCollection(name: "Ideas & Notes", sortPosition: 0)
        let bookmark = Bookmark(
            urlString: "https://example.com/?a=1&b=\"two\"",
            normalizedURLString: "https://example.com/?a=1&b=%22two%22"
        )
        bookmark.title = "A <Useful> \"Link\""
        bookmark.domain = "example.com"
        bookmark.collection = collection
        bookmark.isFavorite = true
        container.mainContext.insert(collection)
        container.mainContext.insert(bookmark)
        try container.mainContext.save()

        let data = try LibraryExportService(context: container.mainContext).exportHTML()
        let html = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(html.contains("<!DOCTYPE NETSCAPE-Bookmark-file-1>"))
        XCTAssertTrue(html.contains("Ideas &amp; Notes"))
        XCTAssertTrue(html.contains("A &lt;Useful&gt; &quot;Link&quot;"))
        XCTAssertTrue(html.contains("HREF=\"https://example.com/?a=1&amp;b=&quot;two&quot;\""))
        XCTAssertTrue(html.contains("TAGS=\"favorite\""))
        XCTAssertEqual(html.components(separatedBy: "https://example.com/?a=1").count - 1, 1)
    }

    func testImageBookmarksAreExcludedFromJSONAndHTMLExport() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/article")
        _ = try repository.saveImage(data: Data([1, 2, 3]), title: "Screenshot")

        let jsonData = try LibraryExportService(context: container.mainContext).exportJSON(
            exportedAt: Date(timeIntervalSince1970: 3_000)
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: jsonData)
        XCTAssertEqual(document.bookmarks.count, 1)
        XCTAssertEqual(document.bookmarks.first?.urlString, "https://example.com/article")

        let htmlData = try LibraryExportService(context: container.mainContext).exportHTML()
        let html = try XCTUnwrap(String(data: htmlData, encoding: .utf8))
        XCTAssertFalse(html.contains("Screenshot"))
        XCTAssertFalse(html.contains("HREF=\"\""))
    }

    func testJSONImportRejectsFutureVersions() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let data = Data("{\"version\":999,\"exportedAt\":\"1970-01-01T00:00:00Z\",\"collections\":[],\"bookmarks\":[]}".utf8)

        XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importJSON(data)) { error in
            XCTAssertEqual(error as? BackupDocument.Error, .unsupportedVersion(999))
        }
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

