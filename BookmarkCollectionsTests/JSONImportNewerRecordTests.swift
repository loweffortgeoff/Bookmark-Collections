import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class JSONImportNewerRecordTests: XCTestCase {
    private let created = Date(timeIntervalSince1970: 1_000)
    private let older = Date(timeIntervalSince1970: 2_000)
    private let current = Date(timeIntervalSince1970: 3_000)
    private let newer = Date(timeIntervalSince1970: 4_000)

    func testRestoredLinkSurvivesOlderExpiredTombstoneAndPurge() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let repository = BookmarkRepository(context: context, isUnlocked: true)
        let bookmark = makeLink()
        context.insert(bookmark)
        let now = Date(timeIntervalSince1970: 4_000_000)
        try repository.softDelete(bookmark, at: now.addingTimeInterval(-31 * 24 * 60 * 60))
        let tombstone = try LibraryExportService(context: context).exportJSON()

        try repository.restore(bookmark)
        let restoredAt = bookmark.modifiedAt
        let collection = BookmarkCollection(name: "Kept collection", sortPosition: 2)
        context.insert(collection)
        bookmark.title = "Restored title"
        bookmark.domain = "kept.example"
        bookmark.collection = collection
        bookmark.isFavorite = true
        bookmark.lastOpenedAt = current
        bookmark.previewImageData = Data([1, 2, 3])
        bookmark.faviconData = Data([4, 5])
        bookmark.metadataState = .ready
        bookmark.lastMetadataRefreshAt = current
        try context.save()
        let id = bookmark.id

        let summary = try LibraryImportService(context: context).importJSON(tombstone)
        try repository.reconcileDuplicates()
        XCTAssertEqual(try repository.purgeExpiredDeleted(now: now), 0)

        let reloaded = ModelContext(container)
        let saved = try XCTUnwrap(reloaded.fetch(FetchDescriptor<Bookmark>()).first { $0.id == id })
        XCTAssertEqual(summary, ImportSummary(duplicateCount: 1))
        XCTAssertNil(saved.deletedAt)
        XCTAssertEqual(saved.urlString, "https://example.com/kept")
        XCTAssertEqual(saved.normalizedURLString, "https://example.com/kept")
        XCTAssertEqual(saved.title, "Restored title")
        XCTAssertEqual(saved.domain, "kept.example")
        XCTAssertEqual(saved.collection?.id, collection.id)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.createdAt, created)
        XCTAssertEqual(saved.modifiedAt, restoredAt)
        XCTAssertEqual(saved.lastOpenedAt, current)
        XCTAssertEqual(saved.previewImageData, Data([1, 2, 3]))
        XCTAssertEqual(saved.faviconData, Data([4, 5]))
        XCTAssertEqual(saved.metadataState, .ready)
        XCTAssertEqual(saved.lastMetadataRefreshAt, current)
    }

    func testNewerDeletedLinkIsNotRestoredByOlderActiveBackup() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let bookmark = makeLink()
        bookmark.deletedAt = current
        bookmark.title = "Deleted later"
        context.insert(bookmark)
        try context.save()

        let summary = try LibraryImportService(context: context).importJSON(encoded(links: [
            link(id: bookmark.id, modifiedAt: older)
        ]))

        XCTAssertEqual(summary, ImportSummary(duplicateCount: 1))
        XCTAssertEqual(bookmark.deletedAt, current)
        XCTAssertEqual(bookmark.modifiedAt, current)
        XCTAssertEqual(bookmark.title, "Deleted later")
    }

    func testNewerSnippetKeepsItsContentOrganizationAndDeletionState() throws {
        for isDeleted in [false, true] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            let collection = BookmarkCollection(name: "Kept", sortPosition: 2)
            context.insert(collection)
            let bookmark = makeLink()
            bookmark.kind = .text
            bookmark.normalizedURLString = ""
            bookmark.urlString = "https://kept.example/source"
            bookmark.domain = "kept.example"
            bookmark.snippetBody = "Newer body"
            bookmark.title = "Newer title"
            bookmark.collection = collection
            bookmark.isFavorite = true
            bookmark.deletedAt = isDeleted ? current : nil
            bookmark.lastOpenedAt = current
            bookmark.previewImageData = Data([1])
            bookmark.faviconData = Data([2])
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = current
            context.insert(bookmark)
            try context.save()

            let summary = try LibraryImportService(context: context).importJSON(encoded(snippets: [
                snippet(id: bookmark.id, modifiedAt: older, deletedAt: isDeleted ? nil : older)
            ]))

            let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
            XCTAssertEqual(summary, ImportSummary(duplicateCount: 1))
            XCTAssertEqual(saved.kind, .text)
            XCTAssertEqual(saved.snippetBody, "Newer body")
            XCTAssertEqual(saved.title, "Newer title")
            XCTAssertEqual(saved.urlString, "https://kept.example/source")
            XCTAssertEqual(saved.domain, "kept.example")
            XCTAssertEqual(saved.normalizedURLString, "")
            XCTAssertEqual(saved.collection?.id, collection.id)
            XCTAssertTrue(saved.isFavorite)
            XCTAssertEqual(saved.createdAt, created)
            XCTAssertEqual(saved.modifiedAt, current)
            XCTAssertEqual(saved.deletedAt, isDeleted ? current : nil)
            XCTAssertEqual(saved.lastOpenedAt, current)
            XCTAssertEqual(saved.previewImageData, Data([1]))
            XCTAssertEqual(saved.faviconData, Data([2]))
            XCTAssertEqual(saved.metadataState, .failed)
            XCTAssertEqual(saved.lastMetadataRefreshAt, current)
        }
    }

    func testNewerCollectionKeepsItsFieldsAndImportedMembership() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let collection = BookmarkCollection(name: "Newer collection", sortPosition: 7,
                                            createdAt: created, modifiedAt: current)
        context.insert(collection)
        try context.save()

        _ = try LibraryImportService(context: context).importJSON(encoded(
            links: [link(modifiedAt: newer, collectionID: collection.id)],
            collections: [collectionRecord(id: collection.id, modifiedAt: older)]
        ))

        XCTAssertEqual(collection.name, "Newer collection")
        XCTAssertEqual(collection.sortPosition, 7)
        XCTAssertEqual(collection.createdAt, created)
        XCTAssertEqual(collection.modifiedAt, current)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Bookmark>()).first?.collection?.id, collection.id)
    }

    func testEqualAndNewerBackupsStillApplyToAllRecordTypes() throws {
        for importedAt in [current, newer] {
            for importDeletion in [false, true] {
                let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
                let context = container.mainContext
                let collection = BookmarkCollection(name: "Local", sortPosition: 7,
                                                    createdAt: created, modifiedAt: current)
                context.insert(collection)
                let bookmark = makeLink()
                bookmark.deletedAt = importDeletion ? nil : current
                bookmark.previewImageData = Data([1])
                bookmark.faviconData = Data([2])
                bookmark.metadataState = .ready
                bookmark.lastMetadataRefreshAt = current
                let text = makeLink()
                text.kind = .text
                text.normalizedURLString = ""
                text.deletedAt = importDeletion ? nil : current
                context.insert(bookmark)
                context.insert(text)
                try context.save()
                let deletedAt = importDeletion ? importedAt : nil

                let summary = try LibraryImportService(context: context).importJSON(encoded(
                    links: [link(id: bookmark.id, modifiedAt: importedAt, deletedAt: deletedAt,
                                 collectionID: collection.id)],
                    snippets: [snippet(id: text.id, modifiedAt: importedAt, deletedAt: deletedAt,
                                       collectionID: collection.id)],
                    collections: [collectionRecord(id: collection.id, modifiedAt: importedAt)]
                ))

                XCTAssertEqual(summary, importDeletion ? ImportSummary(duplicateCount: 2)
                                                       : ImportSummary(restoredCount: 2))
                XCTAssertEqual(bookmark.title, "Backup title")
                XCTAssertEqual(bookmark.collection?.id, collection.id)
                XCTAssertTrue(bookmark.isFavorite)
                XCTAssertEqual(bookmark.modifiedAt, importedAt)
                XCTAssertEqual(bookmark.deletedAt, deletedAt)
                XCTAssertEqual(bookmark.lastOpenedAt, older)
                XCTAssertNil(bookmark.previewImageData)
                XCTAssertNil(bookmark.faviconData)
                XCTAssertEqual(bookmark.metadataState, .pending)
                XCTAssertNil(bookmark.lastMetadataRefreshAt)
                XCTAssertEqual(text.snippetBody, "Backup body")
                XCTAssertEqual(text.urlString, "https://backup.example/source")
                XCTAssertEqual(text.collection?.id, collection.id)
                XCTAssertTrue(text.isFavorite)
                XCTAssertEqual(text.modifiedAt, importedAt)
                XCTAssertEqual(text.deletedAt, deletedAt)
                XCTAssertEqual(text.lastOpenedAt, older)
                XCTAssertEqual(collection.name, "Backup collection")
                XCTAssertEqual(collection.sortPosition, 4)
                XCTAssertEqual(collection.createdAt, older)
                XCTAssertEqual(collection.modifiedAt, importedAt)
            }
        }
    }

    func testOlderRepeatedRecordsCannotOverwriteNewerRecordsWithinOneBackup() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let linkID = UUID()
        let snippetID = UUID()
        let collectionID = UUID()
        let summary = try LibraryImportService(context: container.mainContext).importJSON(encoded(
            links: [link(id: linkID, modifiedAt: newer),
                    link(id: linkID, modifiedAt: older, deletedAt: older)],
            snippets: [snippet(id: snippetID, modifiedAt: newer),
                       snippet(id: snippetID, modifiedAt: older, deletedAt: older)],
            collections: [collectionRecord(id: collectionID, modifiedAt: newer),
                          collectionRecord(id: collectionID, modifiedAt: older)]
        ))

        XCTAssertEqual(summary, ImportSummary(newCount: 2, duplicateCount: 2))
        let saved = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(saved.count, 2)
        XCTAssertTrue(saved.allSatisfy { $0.deletedAt == nil && $0.modifiedAt == newer })
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<BookmarkCollection>()).first?.modifiedAt, newer)
    }

    func testOlderTombstoneCannotFreeCapacityOrMutateRejectedImport() throws {
        for importSnippet in [false, true] {
            try withLockedStore(9) { container in
                let context = container.mainContext
                let victim = makeLink()
                if importSnippet { victim.kind = .text; victim.normalizedURLString = "" }
                victim.title = "Kept title"
                context.insert(victim)
                let collection = BookmarkCollection(name: "Kept collection", sortPosition: 7,
                                                    createdAt: created, modifiedAt: current)
                context.insert(collection)
                try context.save()
                let pending = try XCTUnwrap(context.fetch(FetchDescriptor<Bookmark>()).first { $0.id != victim.id })
                pending.title = "Unsaved edit"
                let data = try encoded(
                    links: (importSnippet ? [] : [link(id: victim.id, modifiedAt: older, deletedAt: older)])
                        + [link(url: "https://example.com/eleventh", modifiedAt: newer)],
                    snippets: importSnippet ? [snippet(id: victim.id, modifiedAt: older, deletedAt: older)] : [],
                    collections: [collectionRecord(id: collection.id, modifiedAt: newer)]
                )

                XCTAssertThrowsError(try LibraryImportService(context: context).importJSON(data)) {
                    XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
                }
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
                XCTAssertNil(victim.deletedAt)
                XCTAssertEqual(victim.modifiedAt, current)
                XCTAssertEqual(victim.title, "Kept title")
                XCTAssertEqual(collection.name, "Kept collection")
                XCTAssertEqual(collection.sortPosition, 7)
                XCTAssertEqual(pending.title, "Unsaved edit")
                XCTAssertTrue(context.hasChanges)
                let persisted = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
                XCTAssertEqual(persisted.count, 10)
                XCTAssertTrue(persisted.allSatisfy { $0.deletedAt == nil && $0.title != "Unsaved edit" })
            }
        }
    }

    func testPreflightTracksDatesOfRepeatedIDsBeforeAnyMutation() throws {
        for importSnippet in [false, true] {
            try withLockedStore(9) { container in
                let id = UUID()
                let data = try encoded(
                    links: importSnippet ? [] : [
                        link(id: id, modifiedAt: newer),
                        link(id: id, modifiedAt: older, deletedAt: older),
                        link(url: "https://example.com/eleventh", modifiedAt: newer)
                    ],
                    snippets: importSnippet ? [
                        snippet(id: id, modifiedAt: newer),
                        snippet(id: id, modifiedAt: older, deletedAt: older),
                        snippet(modifiedAt: newer)
                    ] : []
                )

                XCTAssertThrowsError(try LibraryImportService(context: container.mainContext).importJSON(data)) {
                    XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
                }
                XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 9)
                XCTAssertFalse(container.mainContext.hasChanges)
            }
        }
    }

    func testOlderActiveBackupOfNewerDeletedItemNeedsNoSlotAtCap() throws {
        for importSnippet in [false, true] {
            try withLockedStore(10) { container in
                let bookmark = makeLink()
                if importSnippet { bookmark.kind = .text; bookmark.normalizedURLString = "" }
                bookmark.deletedAt = current
                container.mainContext.insert(bookmark)
                try container.mainContext.save()

                let summary = try LibraryImportService(context: container.mainContext).importJSON(encoded(
                    links: importSnippet ? [] : [link(id: bookmark.id, modifiedAt: older)],
                    snippets: importSnippet ? [snippet(id: bookmark.id, modifiedAt: older)] : []
                ))

                XCTAssertEqual(summary, ImportSummary(duplicateCount: 1))
                XCTAssertEqual(bookmark.deletedAt, current)
                XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 11)
            }
        }
    }

    func testEqualAndNewerTombstonesStillFreeCapacity() throws {
        for importedAt in [current, newer] {
            for importSnippet in [false, true] {
                try withLockedStore(9) { container in
                    let bookmark = makeLink()
                    if importSnippet { bookmark.kind = .text; bookmark.normalizedURLString = "" }
                    container.mainContext.insert(bookmark)
                    try container.mainContext.save()

                    let summary = try LibraryImportService(context: container.mainContext).importJSON(encoded(
                        links: (importSnippet ? [] : [link(id: bookmark.id, modifiedAt: importedAt, deletedAt: importedAt)])
                            + [link(url: "https://example.com/tenth", modifiedAt: newer)],
                        snippets: importSnippet ? [snippet(id: bookmark.id, modifiedAt: importedAt, deletedAt: importedAt)] : []
                    ))

                    XCTAssertEqual(summary, ImportSummary(newCount: 1, duplicateCount: 1))
                    XCTAssertEqual(bookmark.deletedAt, importedAt)
                    XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).filter { $0.deletedAt == nil }.count, 10)
                }
            }
        }
    }

    private func makeLink() -> Bookmark {
        Bookmark(urlString: "https://example.com/kept", normalizedURLString: "https://example.com/kept",
                 createdAt: created, modifiedAt: current)
    }

    private func link(id: UUID = UUID(), url: String = "https://example.com/kept",
                      modifiedAt: Date, deletedAt: Date? = nil,
                      collectionID: UUID? = nil) -> BackupDocument.BookmarkRecord {
        .init(id: id, urlString: url, normalizedURLString: url, title: "Backup title",
              domain: "example.com", isFavorite: true, collectionID: collectionID,
              createdAt: older, modifiedAt: modifiedAt, deletedAt: deletedAt, lastOpenedAt: older)
    }

    private func snippet(id: UUID = UUID(), modifiedAt: Date, deletedAt: Date? = nil,
                         collectionID: UUID? = nil) -> BackupDocument.SnippetRecord {
        .init(id: id, title: "Backup title", body: "Backup body", sourceUrl: "https://backup.example/source",
              isFavorite: true, collectionID: collectionID, createdAt: older,
              modifiedAt: modifiedAt, deletedAt: deletedAt, lastOpenedAt: older)
    }

    private func collectionRecord(id: UUID, modifiedAt: Date) -> BackupDocument.CollectionRecord {
        .init(id: id, name: "Backup collection", sortPosition: 4, createdAt: older, modifiedAt: modifiedAt)
    }

    private func encoded(links: [BackupDocument.BookmarkRecord] = [],
                         snippets: [BackupDocument.SnippetRecord] = [],
                         collections: [BackupDocument.CollectionRecord] = []) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(BackupDocument(exportedAt: newer, collections: collections,
                                               bookmarks: links, snippets: snippets))
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
        XCTAssertTrue(PaywallConfiguration.isEnforced)
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        for index in 0..<count {
            container.mainContext.insert(Bookmark(urlString: "https://example.com/seed/\(index)",
                                                  normalizedURLString: "https://example.com/seed/\(index)",
                                                  createdAt: created, modifiedAt: current))
        }
        try container.mainContext.save()
        try action(container)
    }
}
