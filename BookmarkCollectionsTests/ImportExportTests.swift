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

    func testJSONRoundTripPreservesLastOpenedAt() throws {
        let source = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let openedAt = Date(timeIntervalSince1970: 2_500)
        let bookmark = Bookmark(
            urlString: "https://example.com/opened",
            normalizedURLString: "https://example.com/opened",
            createdAt: Date(timeIntervalSince1970: 1_000),
            modifiedAt: Date(timeIntervalSince1970: 2_000)
        )
        bookmark.lastOpenedAt = openedAt
        source.mainContext.insert(bookmark)
        try source.mainContext.save()

        let data = try LibraryExportService(context: source.mainContext).exportJSON()
        let destination = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try LibraryImportService(context: destination.mainContext).importJSON(data)

        let restored = try XCTUnwrap(
            destination.mainContext.fetch(FetchDescriptor<Bookmark>()).first
        )
        XCTAssertEqual(restored.lastOpenedAt, openedAt)
    }

    func testJSONImportMissingLastOpenedAtDefaultsToNil() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "1970-01-01T00:00:03Z",
          "collections": [],
          "bookmarks": [
            {
              "id": "00000000-0000-0000-0000-000000000020",
              "urlString": "https://example.com/article",
              "normalizedURLString": "https://example.com/article",
              "title": "Title",
              "domain": "example.com",
              "isFavorite": false,
              "collectionID": null,
              "createdAt": "1970-01-01T00:00:01Z",
              "modifiedAt": "1970-01-01T00:00:02Z",
              "deletedAt": null
            }
          ]
        }
        """
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try LibraryImportService(context: container.mainContext)
            .importJSON(Data(json.utf8))
        let restored = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<Bookmark>()).first
        )
        XCTAssertNil(restored.lastOpenedAt)
    }

    func testImportingAGlazeExportRestoresSnippetsAlongsideLinks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "glaze-export", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let service = LibraryImportService(context: container.mainContext)

        let summary = try service.importJSON(data)

        XCTAssertEqual(summary.newCount, 3)
        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        let snippets = bookmarks.filter { $0.kind == .text }
        XCTAssertEqual(snippets.count, 2)

        let titled = try XCTUnwrap(snippets.first { $0.title == "A kept paragraph" })
        XCTAssertEqual(
            titled.snippetBody,
            "The part of the article worth keeping.\nAnd a second line."
        )
        XCTAssertEqual(titled.urlString, "https://example.com/article")
        XCTAssertEqual(titled.domain, "example.com")
        XCTAssertEqual(titled.normalizedURLString, "")
        XCTAssertTrue(titled.isFavorite)
        XCTAssertEqual(titled.collection?.name, "Reading")
        XCTAssertEqual(titled.metadataState, .ready)

        let derived = try XCTUnwrap(snippets.first { $0.title == "Derive my title from this line" })
        XCTAssertEqual(derived.urlString, "")
        XCTAssertEqual(derived.domain, "")
        XCTAssertNil(derived.collection)
    }

    func testImportingTheSameGlazeExportTwiceCreatesNoDuplicates() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "glaze-export", withExtension: "json")
        )
        let data = try Data(contentsOf: url)
        let service = LibraryImportService(context: container.mainContext)
        _ = try service.importJSON(data)

        let summary = try service.importJSON(data)

        XCTAssertEqual(summary.newCount, 0)
        let snippets = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
            .filter { $0.kind == .text }
        XCTAssertEqual(snippets.count, 2)
        XCTAssertEqual(summary.duplicateCount, 3)
    }

    func testJSONRoundTripPreservesSnippets() throws {
        let source = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: source.mainContext)
        let collection = BookmarkCollection(name: "Research", sortPosition: 0)
        source.mainContext.insert(collection)
        let snippet = try repository.saveSnippet(
            title: "Kept",
            body: "Body text worth keeping",
            sourceURL: "https://example.com/source",
            collection: collection,
            favorite: true
        )
        let snippetID = snippet.id

        let data = try LibraryExportService(context: source.mainContext).exportJSON()

        let destination = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try LibraryImportService(context: destination.mainContext).importJSON(data)

        let restored = try XCTUnwrap(
            try destination.mainContext.fetch(FetchDescriptor<Bookmark>())
                .first { $0.id == snippetID }
        )
        XCTAssertEqual(restored.kind, .text)
        XCTAssertEqual(restored.snippetBody, "Body text worth keeping")
        XCTAssertEqual(restored.title, "Kept")
        XCTAssertEqual(restored.urlString, "https://example.com/source")
        XCTAssertTrue(restored.isFavorite)
        XCTAssertEqual(restored.collection?.name, "Research")
    }

    func testJSONExportKeepsSnippetsOutOfTheBookmarksArray() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/link")
        _ = try repository.saveSnippet(body: "Snippet text")

        let data = try LibraryExportService(context: container.mainContext).exportJSON()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(BackupDocument.self, from: data)

        XCTAssertEqual(document.bookmarks.count, 1)
        XCTAssertEqual(document.bookmarks.first?.urlString, "https://example.com/link")
        XCTAssertEqual(document.snippets.count, 1)
        XCTAssertEqual(document.snippets.first?.body, "Snippet text")
    }

    func testHTMLExportOmitsSnippets() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.save(url: "https://example.com/link")
        _ = try repository.saveSnippet(body: "Snippet text that must not ship")

        let data = try LibraryExportService(context: container.mainContext).exportHTML()
        let html = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(html.contains("https://example.com/link"))
        XCTAssertFalse(html.contains("Snippet text that must not ship"))
    }

    func testABackupWithoutASnippetsKeyStillImports() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let legacy = """
        {
          "version": 1,
          "exportedAt": "2026-08-01T09:00:00Z",
          "collections": [],
          "bookmarks": [
            {
              "id": "00000000-0000-0000-0000-0000000000D1",
              "urlString": "https://example.com/legacy",
              "normalizedURLString": "https://example.com/legacy",
              "title": "Legacy",
              "domain": "example.com",
              "isFavorite": false,
              "collectionID": null,
              "createdAt": "2026-08-01T09:00:00Z",
              "modifiedAt": "2026-08-01T09:00:00Z",
              "deletedAt": null,
              "lastOpenedAt": null
            }
          ]
        }
        """
        let service = LibraryImportService(context: container.mainContext)

        let summary = try service.importJSON(Data(legacy.utf8))

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(
            try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count,
            1
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

