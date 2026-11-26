import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class URLDropImportTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.make(inMemory: true, cloudKit: false)
    }

    private func withLockedStore(_ count: Int, _ action: (ModelContainer) throws -> Void) throws {
        let oldAccess = PurchaseAccess.isUnlocked
        let oldAvailability = PurchaseAccess.isProductAvailable
        PurchaseAccess.setUnlocked(false)
        PurchaseAccess.setProductAvailable(true)
        defer {
            PurchaseAccess.setUnlocked(oldAccess)
            PurchaseAccess.setProductAvailable(oldAvailability)
        }
        let container = try makeContainer()
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: true)
        for index in 0..<count { _ = try repository.save(url: "https://audit.example/\(index)") }
        try action(container)
    }

    private func url(_ string: String) -> URL {
        URL(string: string)!
    }

    private func bookmark(_ normalized: String, in context: ModelContext) throws -> Bookmark? {
        try context.fetch(FetchDescriptor<Bookmark>(predicate: #Predicate { $0.normalizedURLString == normalized })).first
    }

    func testDropIntoEmptyLibrarySavesValidLinks() throws {
        let container = try makeContainer()
        let summary = LibraryImportService(context: container.mainContext).importDroppedURLs(
            [url("https://example.com/a"), url("https://example.com/b")],
            collection: nil
        )

        XCTAssertEqual(summary.newCount, 2)
        XCTAssertTrue(summary.failedLines.isEmpty)
        XCTAssertFalse(summary.stoppedAtLimit)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 2)
    }

    func testDropInCollectionAssignsNewLinksAndPreservesExistingOrganization() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let collectionA = BookmarkCollection(name: "A", sortPosition: 0)
        let collectionB = BookmarkCollection(name: "B", sortPosition: 1)
        context.insert(collectionA)
        context.insert(collectionB)
        let repository = BookmarkRepository(context: context, isUnlocked: true)
        _ = try repository.save(url: "https://example.com/existing", collection: collectionA, favorite: true)

        let summary = LibraryImportService(context: context).importDroppedURLs(
            [url("https://example.com/existing"), url("https://example.com/new")],
            collection: collectionB
        )

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(summary.duplicateCount, 1)
        let new = try XCTUnwrap(bookmark("https://example.com/new", in: context))
        XCTAssertEqual(new.collection?.name, "B")
        XCTAssertFalse(new.isFavorite)
        let existing = try XCTUnwrap(bookmark("https://example.com/existing", in: context))
        XCTAssertEqual(existing.collection?.name, "A")
        XCTAssertTrue(existing.isFavorite)
    }

    func testDropSkipsFileURLsSilentlyAndReportsNonFileInvalidURLsWithoutAborting() throws {
        let container = try makeContainer()
        let summary = LibraryImportService(context: container.mainContext).importDroppedURLs([
            url("file:///tmp/photo.png"),
            url("mailto:test@example.com"),
            url("https://valid-1.example"),
            url("https://"),
            url("https://valid-2.example")
        ])

        XCTAssertEqual(summary.newCount, 2)
        XCTAssertEqual(summary.failedLines, ["mailto:test@example.com", "https://"])
        XCTAssertFalse(summary.stoppedAtLimit)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 2)
    }

    func testDropRestoresRecentlyDeletedLinkAndPreservesOrganization() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let repository = BookmarkRepository(context: context, isUnlocked: true)
        guard case let .created(deleted) = try repository.save(url: "https://example.com/deleted", favorite: true) else {
            return XCTFail("Expected a new bookmark")
        }
        try repository.softDelete(deleted)

        let summary = LibraryImportService(context: context).importDroppedURLs([url("https://example.com/deleted")])

        XCTAssertEqual(summary.restoredCount, 1)
        XCTAssertNil(deleted.deletedAt)
        XCTAssertTrue(deleted.isFavorite)
    }

    func testDropStoppingAtFreeLimitKeepsSavedLinksAndFlagsStoppedAtLimit() throws {
        try withLockedStore(9) { container in
            let summary = LibraryImportService(context: container.mainContext).importDroppedURLs([
                url("https://audit.example/drop-a"),
                url("https://audit.example/drop-b"),
                url("https://audit.example/drop-c")
            ])

            XCTAssertEqual(summary.newCount, 1)
            XCTAssertTrue(summary.stoppedAtLimit)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    /// Safari's address bar drags a promised `.webloc` file; SwiftUI delivers
    /// that file URL instead of the web URL.
    func testDropReadsLinkFromSafariWeblocFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let webloc = folder.appendingPathComponent("This Week in Tech.webloc")
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["URL": "https://twit.tv/"], format: .binary, options: 0
        )
        try data.write(to: webloc)

        let container = try makeContainer()
        let context = container.mainContext
        let collection = BookmarkCollection(name: "Test", sortPosition: 0)
        context.insert(collection)

        let summary = LibraryImportService(context: context).importDroppedURLs([webloc], collection: collection)

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertTrue(summary.failedLines.isEmpty)
        let saved = try XCTUnwrap(try context.fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.urlString, "https://twit.tv/")
        XCTAssertEqual(saved.collection?.id, collection.id)
    }
}
