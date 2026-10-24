import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ShareDelayedMetadataTests: XCTestCase {
    func testMetadataAfterSaveCannotOverwriteDurableEditedData() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let existing = Bookmark(urlString: "https://example.com/delayed", normalizedURLString: "https://example.com/delayed")
        existing.title = "My title"
        existing.isFavorite = true
        existing.previewImageData = Data([7])
        context.insert(existing)
        try context.save()
        let provider = DelayedShareMetadata()
        var completions = 0
        let model = ShareCaptureModel(context: context, metadataProvider: provider) { completions += 1 }
        await model.load(from: [NSItemProvider(object: NSURL(string: existing.urlString)!)])
        await provider.waitUntilRequested(count: 1)
        model.save(collectionID: model.selectedCollectionID, favorite: model.isFavorite)
        XCTAssertEqual(completions, 1, "Saving must not wait for the provider")
        await provider.resolveFirst(title: "Late title", image: Data([8]))
        for _ in 0..<1_000 {
            if model.capture?.metadataWasFetched == true { break }
            await Task.yield()
        }
        XCTAssertTrue(model.capture?.metadataWasFetched == true, "Actually observe the late result")
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertEqual(saved.title, "My title")
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.previewImageData, Data([7]))
        XCTAssertEqual(saved.metadataState, .pending)
        XCTAssertNil(saved.lastMetadataRefreshAt)
        XCTAssertEqual(model.state, .saved)
        XCTAssertEqual(completions, 1)
    }

    func testPreviousGenerationOfSameURLCannotPopulateReplacementCapture() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let provider = DelayedShareMetadata()
        let model = ShareCaptureModel(context: container.mainContext, metadataProvider: provider, onComplete: {})
        let first = NSItemProvider(object: NSURL(string: "https://example.com/replaced")!)
        first.suggestedName = "First share"
        await model.load(from: [first])
        await provider.waitUntilRequested(count: 1)
        let second = NSItemProvider(object: NSURL(string: "https://example.com/replaced")!)
        second.suggestedName = "Second share"
        await model.load(from: [second])
        await provider.waitUntilRequested(count: 2)
        await provider.resolveFirst(title: "Stale response", image: Data([8]))
        // Let the resumed MainActor metadata task drain before checking its guard.
        for _ in 0..<1_000 { await Task.yield() }
        XCTAssertEqual(model.capture?.suggestedTitle, "Second share")
        XCTAssertNil(model.capture?.previewImageData)
        XCTAssertFalse(model.capture?.metadataWasFetched ?? true)
        await provider.resolveFirst(title: "Current response", image: Data([9]))
        for _ in 0..<1_000 {
            if model.capture?.suggestedTitle == "Current response" { break }
            await Task.yield()
        }
        XCTAssertEqual(model.capture?.suggestedTitle, "Current response")
        XCTAssertEqual(model.capture?.previewImageData, Data([9]))
    }
}

private actor DelayedShareMetadata: MetadataProviding {
    private var pending: [CheckedContinuation<LinkMetadata, Never>] = []
    private var waiter: (Int, CheckedContinuation<Void, Never>)?

    func metadata(for url: URL) async throws -> LinkMetadata {
        await withCheckedContinuation { continuation in
            pending.append(continuation)
            if let (count, continuation) = waiter, pending.count >= count {
                waiter = nil
                continuation.resume()
            }
        }
    }

    func waitUntilRequested(count: Int) async {
        if pending.count >= count { return }
        await withCheckedContinuation { waiter = (count, $0) }
    }

    func resolveFirst(title: String, image: Data) {
        pending.removeFirst().resume(returning: LinkMetadata(title: title, domain: "example.com", previewImageData: image))
    }
}
