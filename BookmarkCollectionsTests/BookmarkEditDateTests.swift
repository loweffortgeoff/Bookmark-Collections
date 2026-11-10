import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class BookmarkEditDateTests: XCTestCase {
    private let edited = Date(timeIntervalSince1970: 1_000)

    func testOpeningEveryItemKindPreservesPersistedEditDate() throws {
        for kind in Bookmark.Kind.allCases {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let item = makeItem(in: container)
            item.kind = kind
            try container.mainContext.save()
            let opened = Date(timeIntervalSince1970: 3_000)

            try BookmarkRepository(context: container.mainContext).markOpened(item, at: opened)

            let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
            XCTAssertEqual(saved.modifiedAt, edited)
            XCTAssertEqual(saved.lastOpenedAt, opened)
        }
    }

    func testSuccessfulMetadataFetchPreservesEditDateAndAllowsNewerBackupEdit() async throws {
        for explicitRefresh in [false, true] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let item = makeItem(in: container)
            let enricher = MetadataEnricher(context: container.mainContext, provider: EditDateMetadataProvider())
            if explicitRefresh {
                try await enricher.refresh(item)
            } else {
                try await enricher.enrichPending(limit: 1)
            }

            let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
            XCTAssertEqual(saved.modifiedAt, edited)
            XCTAssertEqual(saved.metadataState, .ready)
            XCTAssertNotNil(saved.lastMetadataRefreshAt)
            XCTAssertEqual(saved.title, "Fetched title")
            XCTAssertEqual(saved.previewImageData, Data([1, 2]))

            try importNewerEdit(for: item, in: container)
        }
    }

    func testOpeningDoesNotMakeNewerBackupEditLookOlder() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let item = makeItem(in: container)
        try BookmarkRepository(context: container.mainContext).markOpened(item, at: Date(timeIntervalSince1970: 3_000))

        try importNewerEdit(for: item, in: container)
    }

    func testUserOrganizationAndDeletionChangesStillAdvanceEditDate() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let item = makeItem(in: container)
        let repository = BookmarkRepository(context: context, isUnlocked: true)
        try repository.setFavorite(item, to: true)
        XCTAssertTrue(item.isFavorite)
        XCTAssertGreaterThan(item.modifiedAt, edited)

        item.modifiedAt = edited
        let collectionRepository = CollectionRepository(context: context)
        let collection = try collectionRepository.create(name: "User collection")
        try repository.move(item, to: collection)
        XCTAssertEqual(item.collection?.id, collection.id)
        XCTAssertGreaterThan(item.modifiedAt, edited)

        item.modifiedAt = edited
        try collectionRepository.delete(collection)
        XCTAssertNil(item.collection)
        XCTAssertGreaterThan(item.modifiedAt, edited)

        try repository.softDelete(item, at: Date(timeIntervalSince1970: 4_000))
        XCTAssertEqual(item.deletedAt, Date(timeIntervalSince1970: 4_000))
        XCTAssertEqual(item.modifiedAt, Date(timeIntervalSince1970: 4_000))
        try repository.restore(item)
        XCTAssertNil(item.deletedAt)
        XCTAssertGreaterThan(item.modifiedAt, Date(timeIntervalSince1970: 4_000))
    }

    private func makeItem(in container: ModelContainer) -> Bookmark {
        let item = Bookmark(urlString: "https://example.com/article", normalizedURLString: "https://example.com/article",
                            createdAt: edited, modifiedAt: edited)
        container.mainContext.insert(item)
        return item
    }

    private func importNewerEdit(for item: Bookmark, in container: ModelContainer) throws {
        let backupDate = Date(timeIntervalSince1970: 2_000)
        let record = BackupDocument.BookmarkRecord(
            id: item.id, urlString: item.urlString, normalizedURLString: item.normalizedURLString,
            title: "Backup edit", domain: "example.com", isFavorite: true, collectionID: nil,
            createdAt: edited, modifiedAt: backupDate, deletedAt: nil, lastOpenedAt: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(BackupDocument(exportedAt: backupDate, collections: [], bookmarks: [record]))

        let summary = try LibraryImportService(context: container.mainContext).importJSON(data)

        XCTAssertEqual(summary.duplicateCount, 1)
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.title, "Backup edit")
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.modifiedAt, backupDate)
    }
}

private struct EditDateMetadataProvider: MetadataProviding {
    func metadata(for url: URL) async throws -> LinkMetadata {
        LinkMetadata(title: "Fetched title", domain: "example.com", previewImageData: Data([1, 2]))
    }
}
