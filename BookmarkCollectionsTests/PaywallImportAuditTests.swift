import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class PaywallImportAuditTests: XCTestCase {
    private func withLockedStore(_ count: Int, _ action: (ModelContainer) throws -> Void) throws {
        let oldAccess = PurchaseAccess.isUnlocked
        PurchaseAccess.setUnlocked(false)
        defer { PurchaseAccess.setUnlocked(oldAccess) }
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: true)
        for index in 0..<count { _ = try repository.save(url: "https://audit.example/\(index)") }
        try action(container)
    }

    private func backup(_ urls: [String], collection: Bool = false) throws -> Data {
        let now = Date()
        let document = BackupDocument(exportedAt: now, collections: collection ? [
            .init(id: UUID(), name: "Rejected import collection", sortPosition: 0, createdAt: now, modifiedAt: now)
        ] : [], bookmarks: urls.map {
            .init(id: UUID(), urlString: $0, normalizedURLString: $0, title: "Imported", domain: "audit.example", isFavorite: false, collectionID: nil, createdAt: now, modifiedAt: now, deletedAt: nil, lastOpenedAt: nil)
        })
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    func testTextImportStopsAtTenWithoutCreatingEleventh() throws {
        try withLockedStore(9) { container in
            XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importText("https://audit.example/new-a\nhttps://audit.example/new-b")) {
                XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
            }
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testJSONImportAcceptsExactlyTen() throws {
        try withLockedStore(9) { container in
            _ = try LibraryImportService(context: container.mainContext).importJSON(backup(["https://audit.example/new"]))
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testJSONImportRejectsEleventhBeforeInsertingBookmarks() throws {
        try withLockedStore(10) { container in
            XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importJSON(backup(["https://audit.example/new"])))
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testJSONDuplicateURLAtLimitDoesNotRequireAnotherSlot() throws {
        try withLockedStore(10) { container in
            _ = try LibraryImportService(context: container.mainContext).importJSON(backup(["https://audit.example/0"]))
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testRejectedJSONImportLeavesNoCollectionsOrPendingChanges() throws {
        try withLockedStore(10) { container in
            XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importJSON(backup(["https://audit.example/new"], collection: true)))
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<BookmarkCollection>()), 0)
            XCTAssertFalse(container.mainContext.hasChanges)
        }
    }

    func testDuplicateOnlyTextImportWorksAboveLimit() throws {
        try withLockedStore(12) { container in
            let summary = try LibraryImportService(context: container.mainContext).importText("https://audit.example/0")
            XCTAssertEqual(summary.duplicateCount, 1)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 12)
        }
    }

    func testExistingBackupCanUpdateLibraryAboveLimit() throws {
        try withLockedStore(12) { container in
            let data = try LibraryExportService(context: container.mainContext).exportJSON()
            let summary = try LibraryImportService(context: container.mainContext).importJSON(data)
            XCTAssertEqual(summary.duplicateCount, 12)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 12)
        }
    }

    private func link(
        _ url: String,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        deletedAt: Date? = nil,
        title: String = "Imported",
        favorite: Bool = false,
        collectionID: UUID? = nil
    ) -> BackupDocument.BookmarkRecord {
        .init(id: id, urlString: url, normalizedURLString: url, title: title,
              domain: "audit.example", isFavorite: favorite, collectionID: collectionID,
              createdAt: createdAt, modifiedAt: createdAt, deletedAt: deletedAt, lastOpenedAt: nil)
    }

    private func snippet(
        _ body: String,
        id: UUID = UUID(),
        deletedAt: Date? = nil
    ) -> BackupDocument.SnippetRecord {
        .init(id: id, title: "Imported snippet", body: body, sourceUrl: nil,
              isFavorite: false, collectionID: nil, createdAt: Date(),
              modifiedAt: Date(), deletedAt: deletedAt, lastOpenedAt: nil)
    }

    private func encoded(
        links: [BackupDocument.BookmarkRecord] = [],
        snippets: [BackupDocument.SnippetRecord] = [],
        collections: [BackupDocument.CollectionRecord] = []
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BackupDocument(exportedAt: Date(), collections: collections,
                                               bookmarks: links, snippets: snippets))
    }

    func testRejectedImportPreservesCollectionAndUnrelatedPendingEdits() throws {
        try withLockedStore(10) { container in
            let context = container.mainContext
            let collection = BookmarkCollection(name: "Original collection", sortPosition: 0)
            context.insert(collection)
            try context.save()
            let bookmark = try XCTUnwrap(context.fetch(FetchDescriptor<Bookmark>()).first)
            bookmark.title = "Unsaved user edit"
            let data = try encoded(links: [link("https://audit.example/new")], collections: [
                .init(id: collection.id, name: "Imported rename", sortPosition: 42,
                      createdAt: Date(), modifiedAt: Date())
            ])

            XCTAssertThrowsError(try LibraryImportService(context: context).importJSON(data)) {
                XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
            }
            XCTAssertEqual(collection.name, "Original collection")
            XCTAssertEqual(collection.sortPosition, 0)
            XCTAssertEqual(bookmark.title, "Unsaved user edit")
            XCTAssertTrue(context.hasChanges)
            try context.save()
            let reloaded = ModelContext(container)
            XCTAssertEqual(try reloaded.fetch(FetchDescriptor<BookmarkCollection>()).first?.name,
                           "Original collection")
            XCTAssertTrue(try reloaded.fetch(FetchDescriptor<Bookmark>()).contains {
                $0.id == bookmark.id && $0.title == "Unsaved user edit"
            })
        }
    }

    func testRepeatedNormalizedURLsConsumeOneSlotAndKeepCanonicalFields() throws {
        try withLockedStore(9) { container in
            let context = container.mainContext
            let earlier = Date(timeIntervalSince1970: 1_000)
            let later = earlier.addingTimeInterval(100)
            let canonicalID = UUID()
            let records = [
                link("https://audit.example/new?utm_source=one", id: canonicalID,
                     createdAt: earlier, title: "Earlier", favorite: true),
                link("https://audit.example/new#fragment", createdAt: later, title: "Latest")
            ]
            _ = try LibraryImportService(context: context).importJSON(encoded(links: records))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
            let imported = try XCTUnwrap(context.fetch(FetchDescriptor<Bookmark>()).first {
                $0.normalizedURLString == "https://audit.example/new"
            })
            XCTAssertEqual(imported.id, canonicalID)
            XCTAssertEqual(imported.title, "Latest")
            XCTAssertTrue(imported.isFavorite)
            let reloaded = ModelContext(container)
            XCTAssertEqual(try reloaded.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testRepeatedLinkAndSnippetIDsConsumeOnlyTheirFinalSlots() throws {
        try withLockedStore(8) { container in
            let linkID = UUID()
            let snippetID = UUID()
            let data = try encoded(links: [
                link("https://audit.example/new-a", id: linkID),
                link("https://audit.example/new-b", id: linkID)
            ], snippets: [snippet("First", id: snippetID), snippet("Last", id: snippetID)])
            _ = try LibraryImportService(context: container.mainContext).importJSON(data)
            let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
            XCTAssertEqual(bookmarks.count, 10)
            XCTAssertEqual(bookmarks.first { $0.id == linkID }?.normalizedURLString,
                           "https://audit.example/new-b")
            XCTAssertEqual(bookmarks.first { $0.id == snippetID }?.snippetBody, "Last")
        }
    }

    func testInvalidURLBlankSnippetAndKindCollisionNeedNoSlots() throws {
        try withLockedStore(10) { container in
            let context = container.mainContext
            let existing = try XCTUnwrap(context.fetch(FetchDescriptor<Bookmark>()).first)
            let data = try encoded(links: [link("file:///not-a-web-link")], snippets: [
                snippet("   \n  "), snippet("Collides", id: existing.id)
            ])
            let summary = try LibraryImportService(context: context).importJSON(data)
            XCTAssertEqual(summary.failedLines.count, 2)
            XCTAssertTrue(summary.failedLines.contains("file:///not-a-web-link"))
            XCTAssertEqual(existing.kind, .link)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testLinkSnippetCollisionWithinBackupDoesNotDoubleCount() throws {
        try withLockedStore(9) { container in
            let id = UUID()
            let data = try encoded(links: [link("https://audit.example/new", id: id)],
                                   snippets: [snippet("Collides", id: id)])
            let summary = try LibraryImportService(context: container.mainContext).importJSON(data)
            XCTAssertEqual(summary.failedLines.count, 1)
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testDeletedLinkAndSnippetRestorationConsumeCapacity() throws {
        for restoreSnippet in [false, true] {
            try withLockedStore(9) { container in
                let context = container.mainContext
                let repository = BookmarkRepository(context: context, isUnlocked: true)
                let deleted: Bookmark
                if restoreSnippet {
                    deleted = try repository.saveSnippet(body: "Deleted text")
                } else {
                    guard case let .created(bookmark) = try repository.save(url: "https://audit.example/deleted") else {
                        return XCTFail("Expected a new link")
                    }
                    deleted = bookmark
                }
                try repository.softDelete(deleted)
                _ = try repository.save(url: "https://audit.example/tenth")
                let data = try encoded(
                    links: restoreSnippet ? [] : [link(deleted.urlString, id: deleted.id)],
                    snippets: restoreSnippet ? [snippet("Restored", id: deleted.id)] : []
                )
                XCTAssertThrowsError(try LibraryImportService(context: context).importJSON(data)) {
                    XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
                }
                XCTAssertNotNil(deleted.deletedAt)
                XCTAssertFalse(context.hasChanges)
                try repository.softDelete(try XCTUnwrap(context.fetch(FetchDescriptor<Bookmark>()).first {
                    $0.deletedAt == nil
                }))
                _ = try LibraryImportService(context: context).importJSON(data)
                XCTAssertNil(deleted.deletedAt)
                XCTAssertEqual(try context.fetch(FetchDescriptor<Bookmark>()).filter { $0.deletedAt == nil }.count, 10)
            }
        }
    }

    func testExistingImagesAndSnippetsCountTowardImportLimit() throws {
        try withLockedStore(8) { container in
            let context = container.mainContext
            let repository = BookmarkRepository(context: context, isUnlocked: true)
            _ = try repository.saveImage(data: Data([1, 2, 3]), title: "Image")
            _ = try repository.saveSnippet(body: "Text")
            XCTAssertThrowsError(try LibraryImportService(context: context).importJSON(
                encoded(snippets: [snippet("Eleventh")])
            ))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
        }
    }

    func testFinalDeletedStateOfRepeatedIDDoesNotConsumeSlot() throws {
        try withLockedStore(10) { container in
            let id = UUID()
            _ = try LibraryImportService(context: container.mainContext).importJSON(encoded(links: [
                link("https://audit.example/new", id: id),
                link("https://audit.example/new", id: id, deletedAt: Date())
            ]))
            let records = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
            XCTAssertEqual(records.filter { $0.deletedAt == nil }.count, 10)
            XCTAssertNotNil(records.first { $0.id == id }?.deletedAt)
        }
    }

    func testDeletedCanonicalDuplicateRemainsDeletedWithoutChangingReconciliation() throws {
        try withLockedStore(10) { container in
            let context = container.mainContext
            let deleted = Bookmark(urlString: "https://audit.example/deleted",
                                   normalizedURLString: "https://audit.example/deleted",
                                   createdAt: Date(timeIntervalSince1970: 1_000))
            deleted.deletedAt = Date()
            context.insert(deleted)
            try context.save()
            _ = try LibraryImportService(context: context).importJSON(encoded(links: [
                link("https://audit.example/deleted", createdAt: Date(timeIntervalSince1970: 2_000))
            ]))
            let records = try context.fetch(FetchDescriptor<Bookmark>())
            XCTAssertEqual(records.count, 11)
            XCTAssertEqual(records.filter { $0.deletedAt == nil }.count, 10)
            XCTAssertNotNil(records.first { $0.id == deleted.id }?.deletedAt)
        }
    }

    func testExistingSyncDuplicatesDoNotPermitGrowthBeyondTenUniqueItems() throws {
        try withLockedStore(10) { container in
            let context = container.mainContext
            for index in 0..<2 {
                let url = "https://audit.example/\(index)"
                context.insert(Bookmark(urlString: url, normalizedURLString: url,
                                        createdAt: Date().addingTimeInterval(100)))
            }
            try context.save()
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 12)

            XCTAssertThrowsError(try LibraryImportService(context: context).importJSON(
                encoded(links: [link("https://audit.example/eleventh-unique")])
            )) {
                XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
            }
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 12)
            XCTAssertFalse(context.hasChanges)
        }
    }

}
