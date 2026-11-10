import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class JSONImportKindCollisionTests: XCTestCase {
    private let edited = Date(timeIntervalSince1970: 2_000)

    func testLinkCollisionPreservesNonLinkContentAndReportsConflict() throws {
        for kind in [Bookmark.Kind.image, .text] {
            for deleted in [false, true] {
                for backupDate in [1_000.0, 2_000.0, 3_000.0] {
                    let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
                    let context = container.mainContext
                    let item = makeItem(kind: kind, deleted: deleted)
                    let collection = BookmarkCollection(name: "Kept", sortPosition: 0)
                    context.insert(collection)
                    item.collection = collection
                    context.insert(item)
                    try context.save()

                    let summary = try LibraryImportService(context: context).importJSON(backup([
                        link(id: item.id, modifiedAt: Date(timeIntervalSince1970: backupDate))
                    ]))

                    XCTAssertEqual(summary.newCount, 0)
                    XCTAssertEqual(summary.duplicateCount, 0)
                    XCTAssertEqual(summary.restoredCount, 0)
                    XCTAssertEqual(summary.failedLines.count, 1)
                    XCTAssertTrue(summary.failedLines.first?.contains(item.id.uuidString) == true)
                    let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
                    XCTAssertEqual(saved.kind, kind)
                    XCTAssertEqual(saved.title, "Kept title")
                    XCTAssertEqual(saved.snippetBody, "Kept body")
                    XCTAssertEqual(saved.urlString, "https://source.example/original")
                    XCTAssertEqual(saved.normalizedURLString, "")
                    XCTAssertEqual(saved.domain, "source.example")
                    XCTAssertEqual(saved.previewImageData, Data([1, 2, 3]))
                    XCTAssertEqual(saved.faviconData, Data([4, 5]))
                    XCTAssertEqual(saved.collection?.id, collection.id)
                    XCTAssertTrue(saved.isFavorite)
                    XCTAssertEqual(saved.createdAt, Date(timeIntervalSince1970: 500))
                    XCTAssertEqual(saved.modifiedAt, edited)
                    XCTAssertEqual(saved.deletedAt, deleted ? edited : nil)
                    XCTAssertEqual(saved.lastOpenedAt, edited)
                    XCTAssertEqual(saved.lastMetadataRefreshAt, edited)
                    XCTAssertEqual(saved.metadataState, .ready)
                }
            }
        }
    }

    func testConflictDoesNotStopUnrelatedLinksAndSnippets() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let item = makeItem(kind: .image)
        container.mainContext.insert(item)
        try container.mainContext.save()
        let snippet = BackupDocument.SnippetRecord(
            id: UUID(), title: "Imported snippet", body: "Imported body", sourceUrl: nil,
            isFavorite: false, collectionID: nil, createdAt: edited, modifiedAt: edited,
            deletedAt: nil, lastOpenedAt: nil
        )

        let summary = try LibraryImportService(context: container.mainContext).importJSON(backup([
            link(id: item.id), link()
        ], snippets: [snippet]))

        XCTAssertEqual(summary.newCount, 2)
        XCTAssertEqual(summary.failedLines.count, 1)
        let saved = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(saved.count, 3)
        XCTAssertEqual(saved.first { $0.id == item.id }?.previewImageData, Data([1, 2, 3]))
        XCTAssertEqual(saved.first { $0.id == snippet.id }?.snippetBody, "Imported body")
    }

    func testConflictingTombstoneCannotFreeCapacityForAnotherLink() throws {
        for kind in [Bookmark.Kind.image, .text] {
            try withLockedStore { container in
                let item = makeItem(kind: kind)
                container.mainContext.insert(item)
                try container.mainContext.save()

                XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importJSON(backup([
                    link(id: item.id, deletedAt: Date(timeIntervalSince1970: 3_000)), link()
                ]))) {
                    XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
                }
                XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
                XCTAssertFalse(container.mainContext.hasChanges)
                XCTAssertNil(item.deletedAt)
            }
        }
    }

    func testConflictWithDeletedItemDoesNotConsumeAFreeSlot() throws {
        for kind in [Bookmark.Kind.image, .text] {
            try withLockedStore { container in
                let item = makeItem(kind: kind, deleted: true)
                container.mainContext.insert(item)
                // Nine active links plus this tenth link fill the cap.
                container.mainContext.insert(Bookmark(urlString: "https://seed.example/tenth",
                                                       normalizedURLString: "https://seed.example/tenth"))
                try container.mainContext.save()

                let summary = try LibraryImportService(context: container.mainContext).importJSON(backup([
                    link(id: item.id)
                ]))

                XCTAssertEqual(summary.failedLines.count, 1)
                XCTAssertEqual(summary.restoredCount, 0)
                XCTAssertEqual(item.deletedAt, edited)
                XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 11)
            }
        }
    }

    private func makeItem(kind: Bookmark.Kind, deleted: Bool = false) -> Bookmark {
        let item = Bookmark(urlString: "https://source.example/original", normalizedURLString: "",
                            createdAt: Date(timeIntervalSince1970: 500), modifiedAt: edited)
        item.kind = kind
        item.title = "Kept title"
        item.snippetBody = "Kept body"
        item.domain = "source.example"
        item.previewImageData = Data([1, 2, 3])
        item.faviconData = Data([4, 5])
        item.isFavorite = true
        item.deletedAt = deleted ? edited : nil
        item.lastOpenedAt = edited
        item.lastMetadataRefreshAt = edited
        item.metadataState = .ready
        return item
    }

    private func link(id: UUID = UUID(), modifiedAt: Date = Date(timeIntervalSince1970: 3_000),
                      deletedAt: Date? = nil) -> BackupDocument.BookmarkRecord {
        .init(id: id, urlString: "https://import.example/link", normalizedURLString: "https://import.example/link",
              title: "Incoming link", domain: "import.example", isFavorite: false, collectionID: nil,
              createdAt: modifiedAt, modifiedAt: modifiedAt, deletedAt: deletedAt, lastOpenedAt: nil)
    }

    private func backup(_ links: [BackupDocument.BookmarkRecord],
                        snippets: [BackupDocument.SnippetRecord] = []) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BackupDocument(exportedAt: edited, collections: [], bookmarks: links, snippets: snippets))
    }

    private func withLockedStore(_ action: (ModelContainer) throws -> Void) throws {
        let oldAccess = PurchaseAccess.isUnlocked
        let oldAvailability = PurchaseAccess.isProductAvailable
        PurchaseAccess.setUnlocked(false)
        PurchaseAccess.setProductAvailable(true)
        defer {
            PurchaseAccess.setUnlocked(oldAccess)
            PurchaseAccess.setProductAvailable(oldAvailability)
        }
        XCTAssertTrue(PaywallConfiguration.isEnforced)
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        for index in 0..<9 {
            container.mainContext.insert(Bookmark(urlString: "https://seed.example/\(index)",
                                                   normalizedURLString: "https://seed.example/\(index)"))
        }
        try container.mainContext.save()
        try action(container)
    }
}
