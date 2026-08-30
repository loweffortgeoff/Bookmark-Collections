import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import BookmarkCollections

@MainActor
final class ShareCaptureModelTests: XCTestCase {
    func testShareStorageRecoveryMessageDoesNotExposeTechnicalError() {
        let error = NSError(
            domain: "Store",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Database at /private/var/mobile failed to open."]
        )

        let message = ShareStorageDiagnostics.recoveryMessage(for: error)

        XCTAssertEqual(message, "Tucked could not open its shared library. Open Tucked, then try sharing again.")
        XCTAssertFalse(message.contains("/private"))
    }

    func testURLAttachmentLoadsImmediately() async throws {
        let model = try makeModel()
        let url = try XCTUnwrap(URL(string: "https://example.com/article"))

        await model.load(from: [NSItemProvider(object: url as NSURL)])

        XCTAssertEqual(model.capture?.urlString, url.absoluteString)
        XCTAssertEqual(model.state, .ready)
    }

    func testPlainTextContainingAURLLoads() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(object: "Read https://example.com/from-text later" as NSString)

        await model.load(from: [provider])

        XCTAssertEqual(model.capture?.urlString, "https://example.com/from-text")
        XCTAssertEqual(model.state, .ready)
    }

    func testUnsupportedInputReportsAUsefulError() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(item: Data([0x01]) as NSData, typeIdentifier: UTType.data.identifier)

        await model.load(from: [provider])

        guard case let .failed(message) = model.state else {
            return XCTFail("Expected unsupported input to fail")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("web link"))
    }

    func testSavePersistsBeforeCallingCompletion() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        var completedAfterSave = false
        let model = ShareCaptureModel(context: container.mainContext) {
            completedAfterSave = (try? container.mainContext.fetch(FetchDescriptor<Bookmark>()).count) == 1
        }
        let provider = NSItemProvider(object: NSURL(string: "https://example.com/offline")!)
        await model.load(from: [provider])

        model.save(collectionID: nil, favorite: true)

        let bookmark = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertTrue(completedAfterSave)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertEqual(bookmark.metadataState, .pending)
        XCTAssertEqual(model.state, .saved)
    }

    func testQuickSaveUsesDefaultOrganizationAndCompletesAfterSave() async throws {
        var saveWasCalled = false
        var receivedCollectionID: UUID? = UUID()
        var receivedFavorite = true
        var completedAfterSave = false
        let model = ShareCaptureModel(
            collections: [],
            saveAction: { capture, collectionID, favorite in
                saveWasCalled = true
                receivedCollectionID = collectionID
                receivedFavorite = favorite
                return .created(
                    Bookmark(
                        urlString: capture.urlString,
                        normalizedURLString: capture.urlString
                    )
                )
            },
            onComplete: {
                completedAfterSave = saveWasCalled
            }
        )
        let provider = NSItemProvider(
            object: NSURL(string: "https://example.com/quick-save")!
        )

        await model.quickSave(from: [provider])

        XCTAssertTrue(saveWasCalled)
        XCTAssertNil(receivedCollectionID)
        XCTAssertFalse(receivedFavorite)
        XCTAssertTrue(completedAfterSave)
        XCTAssertEqual(model.state, .saved)
    }

    func testQuickSaveUnsupportedInputDoesNotSaveOrComplete() async {
        var didSave = false
        var didComplete = false
        let model = ShareCaptureModel(
            collections: [],
            saveAction: { _, _, _ in
                didSave = true
                return .created(
                    Bookmark(urlString: "", normalizedURLString: "")
                )
            },
            onComplete: {
                didComplete = true
            }
        )
        let provider = NSItemProvider(
            item: Data([0x01]) as NSData,
            typeIdentifier: UTType.data.identifier
        )

        await model.quickSave(from: [provider])

        XCTAssertFalse(didSave)
        XCTAssertFalse(didComplete)
        guard case let .failed(message) = model.state else {
            return XCTFail("Expected unsupported input to fail")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("web link"))
    }

    func testQuickSaveCanRetryAfterSaveFailure() async {
        var attempts = 0
        var completions = 0
        let model = ShareCaptureModel(
            collections: [],
            saveAction: { capture, _, _ in
                attempts += 1
                if attempts == 1 {
                    throw TestError.storeUnavailable
                }
                return .created(
                    Bookmark(
                        urlString: capture.urlString,
                        normalizedURLString: capture.urlString
                    )
                )
            },
            onComplete: {
                completions += 1
            }
        )
        let provider = NSItemProvider(
            object: NSURL(string: "https://example.com/quick-save-retry")!
        )

        await model.quickSave(from: [provider])

        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(completions, 0)
        guard case .failed = model.state else {
            return XCTFail("Expected the first save to fail")
        }

        await model.quickSave(from: [provider])

        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(model.state, .saved)
    }

    func testStoreFailureDoesNotCallCompletion() async throws {
        var didComplete = false
        let model = ShareCaptureModel(
            collections: [],
            saveAction: { _, _, _ in throw TestError.storeUnavailable },
            onComplete: { didComplete = true }
        )
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/failure")!)])

        model.save(collectionID: nil, favorite: false)

        XCTAssertFalse(didComplete)
        guard case let .failed(message) = model.state else {
            return XCTFail("Expected the store failure to remain visible")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("save"))
    }

    func testLimitReachedTellsThePersonToOpenTucked() async throws {
        let model = ShareCaptureModel(
            collections: [],
            saveAction: { _, _, _ in throw BookmarkRepository.LimitError.limitReached },
            onComplete: {}
        )
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/limit")!)])

        model.save(collectionID: nil, favorite: false)

        guard case let .failed(message) = model.state else {
            return XCTFail("Expected the free-tier limit to remain visible")
        }
        XCTAssertTrue(message.localizedCaseInsensitiveContains("open tucked"))
    }

    func testDuplicateSaveUpdatesTheExistingBookmark() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let existing = try bookmark(from: repository.save(url: "https://example.com/duplicate"))
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        container.mainContext.insert(collection)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/duplicate")!)])

        model.save(collectionID: collection.id, favorite: true)

        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.id, existing.id)
        XCTAssertEqual(bookmarks.first?.collection?.id, collection.id)
        XCTAssertTrue(bookmarks.first?.isFavorite == true)
    }

    func testDuplicateSaveRestoresARecentlyDeletedBookmark() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let deleted = Bookmark(
            urlString: "https://example.com/restored",
            normalizedURLString: "https://example.com/restored"
        )
        deleted.deletedAt = Date()
        container.mainContext.insert(deleted)
        try container.mainContext.save()
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/restored")!)])

        model.save(collectionID: nil, favorite: false)

        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks.first?.id, deleted.id)
        XCTAssertNil(bookmarks.first?.deletedAt)
    }

    func testImageAttachmentLoadsAsImageCapture() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(
            item: try onePixelPNG() as NSData,
            typeIdentifier: UTType.png.identifier
        )

        await model.load(from: [provider])

        XCTAssertEqual(model.capture?.kind, .image)
        XCTAssertNotNil(model.capture?.previewImageData)
        XCTAssertEqual(model.capture?.urlString, "")
        XCTAssertEqual(model.state, .ready)
    }

    func testImageSavePersistsImageBookmark() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let provider = NSItemProvider(
            item: try onePixelPNG() as NSData,
            typeIdentifier: UTType.png.identifier
        )
        await model.load(from: [provider])

        model.save(collectionID: nil, favorite: true)

        let bookmark = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(bookmark.kind, .image)
        XCTAssertNotNil(bookmark.previewImageData)
        XCTAssertTrue(bookmark.urlString.isEmpty)
        XCTAssertTrue(bookmark.isFavorite)
        XCTAssertFalse(bookmark.title.isEmpty)
        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(model.state, .saved)
    }

    func testImageSaveAssignsCollectionAndFavorite() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collection = BookmarkCollection(name: "Reference", sortPosition: 0)
        container.mainContext.insert(collection)
        try container.mainContext.save()
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let provider = NSItemProvider(
            item: try onePixelPNG() as NSData,
            typeIdentifier: UTType.png.identifier
        )
        await model.load(from: [provider])

        model.save(collectionID: collection.id, favorite: true)

        let bookmark = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<Bookmark>()).first
        )
        XCTAssertEqual(bookmark.kind, .image)
        XCTAssertEqual(bookmark.collection?.id, collection.id)
        XCTAssertTrue(bookmark.isFavorite)
    }

    func testJunkDataTypedAsImageFails() async throws {
        let model = try makeModel()
        let provider = NSItemProvider(
            item: Data([0x00, 0x01, 0x02]) as NSData,
            typeIdentifier: UTType.png.identifier
        )

        await model.load(from: [provider])

        guard case .failed = model.state else {
            return XCTFail("Expected junk image data to fail")
        }
    }

    /// Smallest valid PNG: 1x1 transparent pixel.
    private func onePixelPNG() throws -> Data {
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
        return try XCTUnwrap(Data(base64Encoded: base64))
    }

    private func makeModel() throws -> ShareCaptureModel {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        return ShareCaptureModel(context: container.mainContext, onComplete: {})
    }

    private func bookmark(from result: SaveResult) throws -> Bookmark {
        switch result {
        case let .created(bookmark), let .updated(bookmark), let .restored(bookmark):
            bookmark
        }
    }

    private enum TestError: Error {
        case storeUnavailable
    }
}
