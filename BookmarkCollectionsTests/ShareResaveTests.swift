import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import BookmarkCollections

@MainActor
final class ShareResaveTests: XCTestCase {
    func testQuickResavePreservesUserDataAndReloadsAtCapacity() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        context.insert(collection)
        let existing = Bookmark(urlString: "https://example.com/saved", normalizedURLString: "https://example.com/saved")
        existing.title = "My edited title"
        existing.collection = collection
        existing.isFavorite = true
        existing.faviconData = Data([1, 2])
        existing.previewImageData = Data([3, 4])
        existing.metadataState = .ready
        context.insert(existing)
        for index in 0..<10 {
            context.insert(Bookmark(urlString: "https://example.com/\(index)", normalizedURLString: "https://example.com/\(index)"))
        }
        try context.save()
        let id = existing.id
        let date = existing.createdAt
        var completed = false
        let model = ShareCaptureModel(context: context) { completed = true }
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/saved?utm_source=test#fragment")!)
        provider.suggestedName = "Provider title"
        await model.quickSave(from: [provider])

        XCTAssertTrue(completed)
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(reloaded.count, 11)
        let saved = try XCTUnwrap(reloaded.first { $0.id == id })
        XCTAssertEqual(saved.createdAt, date)
        XCTAssertEqual(saved.title, "My edited title")
        XCTAssertEqual(saved.collection?.id, collection.id)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.faviconData, Data([1, 2]))
        XCTAssertEqual(saved.previewImageData, Data([3, 4]))
    }

    func testSuggestedNameDoesNotCompleteMetadataEnrichment() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/new")!)
        provider.suggestedName = "Suggested title"
        await model.quickSave(from: [provider])
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.title, "Suggested title")
        XCTAssertEqual(saved.metadataState, .pending)
        XCTAssertNil(saved.lastMetadataRefreshAt)
    }

    func testDeletedQuickResavePreservesOrganization() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let existing = Bookmark(urlString: "https://example.com/deleted", normalizedURLString: "https://example.com/deleted")
        existing.title = "Keep me"
        existing.isFavorite = true
        existing.deletedAt = Date()
        container.mainContext.insert(existing)
        try container.mainContext.save()
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: existing.urlString)!)])
        XCTAssertNil(existing.deletedAt)
        XCTAssertTrue(existing.isFavorite)
        XCTAssertEqual(existing.title, "Keep me")
    }
    func testInteractiveControlsLoadExistingValuesThenAllowExplicitNoneAndOff() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        context.insert(collection)
        let existing = Bookmark(urlString: "https://example.com/control", normalizedURLString: "https://example.com/control")
        existing.collection = collection
        existing.isFavorite = true
        context.insert(existing)
        try context.save()
        let model = ShareCaptureModel(context: context, onComplete: {})
        await model.load(from: [NSItemProvider(object: NSURL(string: existing.urlString)!)])
        XCTAssertEqual(model.selectedCollectionID, collection.id)
        XCTAssertTrue(model.isFavorite)
        model.selectedCollectionID = nil
        model.isFavorite = false
        model.save(collectionID: model.selectedCollectionID, favorite: model.isFavorite)
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertNil(saved.collection)
        XCTAssertFalse(saved.isFavorite)
    }

    func testDifferentCaptureResetsInteractiveOrganization() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/first")!)])
        model.selectedCollectionID = UUID()
        model.isFavorite = true
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/second")!)])
        XCTAssertNil(model.selectedCollectionID)
        XCTAssertFalse(model.isFavorite)
    }

    func testRestoringAtCapacityLeavesDeletedRecordUntouched() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let deleted = Bookmark(urlString: "https://example.com/deleted", normalizedURLString: "https://example.com/deleted")
        deleted.deletedAt = Date()
        deleted.title = "Preserved"
        deleted.isFavorite = true
        context.insert(deleted)
        for index in 0..<10 {
            context.insert(Bookmark(urlString: "https://example.com/\(index)", normalizedURLString: "https://example.com/\(index)"))
        }
        try context.save()
        let repository = BookmarkRepository(context: context, isUnlocked: false, paywallEnabled: true)
        XCTAssertThrowsError(try repository.saveSharedLink(
            url: deleted.urlString, collection: nil, favorite: false, preserveOrganization: true,
            suggestedTitle: "Replacement", faviconData: nil, previewImageData: nil, metadataWasFetched: false
        ))
        XCTAssertNotNil(deleted.deletedAt)
        XCTAssertTrue(deleted.isFavorite)
        XCTAssertEqual(deleted.title, "Preserved")
        XCTAssertFalse(context.hasChanges)
    }

    func testMetadataFillsOnlyMissingFieldsWithoutOverwritingEditedTitle() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let existing = Bookmark(urlString: "https://example.com/meta", normalizedURLString: "https://example.com/meta")
        existing.title = "Edited while sharing"
        existing.faviconData = Data([9])
        context.insert(existing)
        try context.save()
        _ = try BookmarkRepository(context: context).saveSharedLink(
            url: existing.urlString, collection: nil, favorite: false, preserveOrganization: true,
            suggestedTitle: "Fetched title", faviconData: Data([1]), previewImageData: Data([2]), metadataWasFetched: true
        )
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.title, "Edited while sharing")
        XCTAssertEqual(saved.faviconData, Data([9]))
        XCTAssertEqual(saved.previewImageData, Data([2]))
        XCTAssertEqual(saved.metadataState, .ready)
    }

}
