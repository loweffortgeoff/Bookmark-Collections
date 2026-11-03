import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import BookmarkCollections

@MainActor
final class ShareSnippetCaptureTests: XCTestCase {
    func testSafariPageDescriptionDoesNotTurnAnOrdinaryLinkIntoSnippet() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Support — Low Effort Apps")
        item.attachments = [NSItemProvider(object: NSURL(string: "https://www.loweffortapps.app/support/")!)]

        await model.load(items: [item])
        model.save(collectionID: nil, favorite: false)

        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.kind, .link)
        XCTAssertEqual(saved.urlString, "https://www.loweffortapps.app/support/")
        XCTAssertEqual(saved.snippetBody, "")
    }

    func testImageWithDescriptiveTextRemainsAnImage() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "A photo caption.")
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
        item.attachments = [NSItemProvider(item: png as NSData, typeIdentifier: UTType.png.identifier)]

        await model.load(items: [item])

        XCTAssertEqual(model.capture?.kind, .image)
        XCTAssertNotNil(model.capture?.previewImageData)
    }

    func testSnippetNeverRequestsPageMetadata() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, metadataProvider: UnexpectedMetadata(), onComplete: {})
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Café 🐾\n\nKeep  these spaces.")
        item.attachments = [
            NSItemProvider(object: "Café 🐾\n\nKeep  these spaces." as NSString),
            NSItemProvider(object: NSURL(string: "https://example.com/source")!)
        ]

        await model.load(items: [item])
        model.save(collectionID: nil, favorite: false)

        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.snippetBody, "Café 🐾\n\nKeep  these spaces.")
        XCTAssertNil(saved.previewImageData)
        XCTAssertEqual(saved.metadataState, .ready)
    }

    func testInvalidSourceDoesNotBlockSnippetSaving() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Selected text.")
        item.attachments = [NSItemProvider(object: NSURL(string: "file:///private/source")!)]

        await model.quickSave(items: [item])

        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.kind, .text)
        XCTAssertEqual(saved.snippetBody, "Selected text.")
        XCTAssertEqual(saved.urlString, "")
    }

    func testQuickSaveRetryRetainsTextWithoutAttachments() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        var attempts = 0
        var completions = 0
        let model = ShareCaptureModel(collections: [], saveAction: { capture, _, _ in
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileWriteNoPermission) }
            return .created(try BookmarkRepository(context: container.mainContext).saveSnippet(body: capture.snippetBody))
        }, onComplete: { completions += 1 })
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Keep these words on retry.")

        await model.quickSave(items: [item])
        XCTAssertEqual(model.failureReason, .saveFailed)
        XCTAssertEqual(completions, 0)
        await model.quickSave(items: [item])

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(model.state, .saved)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first?.snippetBody, "Keep these words on retry.")
    }

    func testProseWithAnEmbeddedURLStaysWhole() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let body = "Read https://example.com/article later.\nKeep this paragraph too."

        await model.load(from: [NSItemProvider(object: body as NSString)])

        XCTAssertEqual(model.capture?.kind, .text)
        XCTAssertEqual(model.capture?.snippetBody, body)
        XCTAssertEqual(model.capture?.urlString, "")
        XCTAssertEqual(model.state, .ready)
    }

    func testSelectedTextWinsOverPageURLInEitherAttachmentOrder() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let source = NSItemProvider(object: NSURL(string: "https://example.com/source")!)
        let selection = NSItemProvider(object: "The selected words." as NSString)

        for providers in [[source, selection], [selection, source]] {
            await model.load(from: providers)
            XCTAssertEqual(model.capture?.kind, .text)
            XCTAssertEqual(model.capture?.snippetBody, "The selected words.")
            XCTAssertEqual(model.capture?.urlString, "https://example.com/source")
        }
    }

    func testAttributedTextWithoutAttachmentsPersistsBeforeCompletion() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "  The selected words.\nA second line.  ")
        var persistedBody: String?
        let model = ShareCaptureModel(context: container.mainContext) {
            persistedBody = try? ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first?.snippetBody
        }

        await model.load(items: [item])
        model.save(collectionID: nil, favorite: false)

        XCTAssertEqual(persistedBody, "The selected words.\nA second line.")
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.kind, .text)
        XCTAssertEqual(saved.title, "The selected words.")
        XCTAssertEqual(saved.normalizedURLString, "")
        XCTAssertEqual(saved.urlString, "")
        XCTAssertEqual(saved.metadataState, .ready)
    }

    func testAttributedSelectionKeepsItsOwnSourceAndOrganization() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        container.mainContext.insert(collection)
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "Selected prose, not the page title.")
        item.attributedTitle = NSAttributedString(string: "Page title")
        item.attachments = [
            NSItemProvider(object: "Selected prose, not the page title." as NSString),
            NSItemProvider(object: NSURL(string: "https://example.com/source#section")!)
        ]
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})

        await model.load(items: [item])
        model.save(collectionID: collection.id, favorite: true)

        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.snippetBody, "Selected prose, not the page title.")
        XCTAssertEqual(saved.title, "Selected prose, not the page title.")
        XCTAssertEqual(saved.urlString, "https://example.com/source#section")
        XCTAssertEqual(saved.normalizedURLString, "")
        XCTAssertEqual(saved.collection?.id, collection.id)
        XCTAssertTrue(saved.isFavorite)
    }

    func testSeparateItemsDoNotGiveASelectionAnotherItemsURL() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let selection = NSExtensionItem()
        selection.attributedContentText = NSAttributedString(string: "Selection without a source.")
        let other = NSExtensionItem()
        other.attachments = [NSItemProvider(object: NSURL(string: "https://example.com/unrelated")!)]
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})

        for items in [[selection, other], [other, selection]] {
            await model.load(items: items)
            XCTAssertEqual(model.capture?.kind, .text)
            XCTAssertEqual(model.capture?.snippetBody, "Selection without a source.")
            XCTAssertEqual(model.capture?.urlString, "")
        }
    }

    func testBareTextURLRemainsALink() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})

        await model.load(from: [NSItemProvider(object: "  https://example.com/article  " as NSString)])

        XCTAssertEqual(model.capture?.kind, .link)
        XCTAssertEqual(model.capture?.urlString, "https://example.com/article")
    }

    func testProseBeginningWithURLRemainsASnippet() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let body = "https://example.com/article is worth reading."

        await model.load(from: [NSItemProvider(object: body as NSString)])

        XCTAssertEqual(model.capture?.kind, .text)
        XCTAssertEqual(model.capture?.snippetBody, body)
    }

    func testBlankTextFallsBackToURLAndBlankOnlyIsUnsupported() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let model = ShareCaptureModel(context: container.mainContext, onComplete: {})
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: " \n ")
        item.attachments = [NSItemProvider(object: NSURL(string: "https://example.com/source")!)]

        await model.load(items: [item])
        XCTAssertEqual(model.capture?.kind, .link)
        item.attachments = nil
        await model.load(items: [item])
        XCTAssertNil(model.capture)
        XCTAssertEqual(model.failureReason, .unsupportedInput)
    }

    func testQuickSaveTextDoesNotUpdateALinkWithTheSameSource() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let existing = Bookmark(urlString: "https://example.com/source", normalizedURLString: "https://example.com/source")
        existing.title = "My saved link"
        context.insert(existing)
        try context.save()
        let item = NSExtensionItem()
        item.attributedContentText = NSAttributedString(string: "A passage from this page.")
        item.attachments = [
            NSItemProvider(object: "A passage from this page." as NSString),
            NSItemProvider(object: NSURL(string: existing.urlString)!)
        ]
        let model = ShareCaptureModel(context: context, onComplete: {})

        await model.quickSave(items: [item])
        await model.quickSave(items: [item])

        let saved = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(saved.count, 3)
        XCTAssertEqual(saved.filter { $0.kind == .text }.count, 2)
        XCTAssertEqual(existing.title, "My saved link")
        XCTAssertTrue(saved.filter { $0.kind == .text }.allSatisfy { $0.collection == nil && !$0.isFavorite })
    }

    func testSnippetAtCapacityDoesNotCompleteOrInsert() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        for index in 0..<10 {
            context.insert(Bookmark(urlString: "https://example.com/\(index)", normalizedURLString: "https://example.com/\(index)"))
        }
        try context.save()
        let repository = BookmarkRepository(context: context, isUnlocked: false, paywallEnabled: true)
        var completed = false
        let model = ShareCaptureModel(collections: [], saveAction: { capture, _, _ in
            .created(try repository.saveSnippet(body: capture.snippetBody, sourceURL: capture.urlString))
        }, onComplete: { completed = true })

        await model.quickSave(from: [NSItemProvider(object: "A new snippet." as NSString)])

        XCTAssertFalse(completed)
        XCTAssertEqual(model.failureReason, .limitReached)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Bookmark>()), 10)
    }
}

private struct UnexpectedMetadata: MetadataProviding {
    func metadata(for url: URL) async throws -> LinkMetadata {
        XCTFail("A snippet must not fetch source-page metadata")
        return LinkMetadata(title: "Page title", domain: "example.com")
    }
}
