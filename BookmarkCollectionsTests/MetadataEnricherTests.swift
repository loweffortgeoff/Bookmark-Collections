import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class MetadataEnricherTests: XCTestCase {
    func testSuccessStoresMetadataAndMarksBookmarkReady() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        let metadata = LinkMetadata(
            title: "Example Article",
            domain: "example.com",
            faviconData: Data([1, 2]),
            previewImageData: Data([3, 4])
        )
        let provider = StubMetadataProvider(results: [.success(metadata)])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.title, "Example Article")
        XCTAssertEqual(bookmark.domain, "example.com")
        XCTAssertEqual(bookmark.faviconData, Data([1, 2]))
        XCTAssertEqual(bookmark.previewImageData, Data([3, 4]))
        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertNotNil(bookmark.lastMetadataRefreshAt)
    }

    func testFailurePreservesURLAndCanRetrySuccessfully() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        let provider = StubMetadataProvider(results: [
            .failure(.failed),
            .success(LinkMetadata(title: "Recovered", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.urlString, "https://example.com/article")
        XCTAssertEqual(bookmark.metadataState, .failed)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.title, "Recovered")
        XCTAssertEqual(bookmark.metadataState, .ready)
    }

    func testPendingEnrichmentRetriesFailedBookmarksAfterInterval() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        let provider = StubMetadataProvider(results: [
            .failure(.failed),
            .success(LinkMetadata(
                title: "Recovered",
                domain: "example.com",
                previewImageData: Data([3, 4])
            ))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)
        XCTAssertEqual(bookmark.metadataState, .failed)

        bookmark.lastMetadataRefreshAt = Date(
            timeIntervalSinceNow: -(MetadataEnricher.failedRetryInterval + 60)
        )
        try container.mainContext.save()

        try await enricher.enrichPending(limit: 10)

        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(bookmark.title, "Recovered")
        XCTAssertEqual(bookmark.previewImageData, Data([3, 4]))
        let retryCallCount = await provider.callCount
        XCTAssertEqual(retryCallCount, 2)
    }

    func testPendingEnrichmentSkipsFreshFailures() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        let provider = StubMetadataProvider(results: [
            .failure(.failed),
            .success(LinkMetadata(title: "Should not load", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)
        try await enricher.enrichPending(limit: 10)

        XCTAssertEqual(bookmark.metadataState, .failed)
        let skippedCallCount = await provider.callCount
        XCTAssertEqual(skippedCallCount, 1)
    }

    func testRefreshKeepsExistingPreviewWhenMetadataOmitsOne() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        bookmark.faviconData = Data([7])
        bookmark.previewImageData = Data([9, 9])
        bookmark.metadataState = .ready
        try container.mainContext.save()
        let provider = StubMetadataProvider(results: [
            .success(LinkMetadata(title: "No image", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.faviconData, Data([7]))
        XCTAssertEqual(bookmark.previewImageData, Data([9, 9]))
        XCTAssertEqual(bookmark.metadataState, .ready)
    }

    func testEnrichmentKeepsAnExistingTitle() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        bookmark.title = "My Title"
        try container.mainContext.save()
        let provider = StubMetadataProvider(results: [
            .success(LinkMetadata(title: "Page Title", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.enrichPending(limit: 1)

        XCTAssertEqual(bookmark.title, "My Title")
        XCTAssertEqual(bookmark.metadataState, .ready)
    }

    func testRefreshKeepsAnExistingTitle() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        bookmark.title = "My Title"
        try container.mainContext.save()
        let provider = StubMetadataProvider(results: [
            .success(LinkMetadata(title: "Page Title", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.title, "My Title")
        XCTAssertEqual(bookmark.metadataState, .ready)
    }

    func testEnrichmentFillsAWhitespaceOnlyTitle() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        bookmark.title = "  \n"
        try container.mainContext.save()
        let provider = StubMetadataProvider(results: [
            .success(LinkMetadata(title: "Page Title", domain: "example.com"))
        ])
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(bookmark)

        XCTAssertEqual(bookmark.title, "Page Title")
    }

    func testPendingEnrichmentRespectsLimit() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try makeBookmark(in: container, path: "one")
        _ = try makeBookmark(in: container, path: "two")
        _ = try makeBookmark(in: container, path: "three")
        let provider = StubMetadataProvider(results: Array(
            repeating: .success(LinkMetadata(title: "Loaded", domain: "example.com")),
            count: 3
        ))
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.enrichPending(limit: 2)

        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        let callCount = await provider.callCount
        XCTAssertEqual(bookmarks.filter { $0.metadataState == .ready }.count, 2)
        XCTAssertEqual(bookmarks.filter { $0.metadataState == .pending }.count, 1)
        XCTAssertEqual(callCount, 2)
        XCTAssertFalse(container.mainContext.hasChanges, "Each completed result must be saved")
    }

    func testPendingEnrichmentSkipsSoftDeletedLinks() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let pending = try makeBookmark(in: container, path: "pending")
        let failed = try makeBookmark(in: container, path: "failed")
        pending.deletedAt = Date()
        failed.deletedAt = Date()
        failed.metadataState = .failed
        let provider = StubMetadataProvider(results: Array(
            repeating: .success(LinkMetadata(title: "Should not load", domain: "example.com")),
            count: 3
        ))
        try container.mainContext.save()
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.enrichPending(limit: 20)
        try await enricher.refresh(pending)

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(pending.metadataState, .pending)
        XCTAssertEqual(failed.metadataState, .failed)
        XCTAssertNil(pending.lastMetadataRefreshAt)
        XCTAssertNil(failed.lastMetadataRefreshAt)
    }

    func testEnrichmentSurvivesDeletionDuringFetch() async throws {
        try await assertEnrichmentSurvivesDeletion(
            result: .success(LinkMetadata(title: "Loaded", domain: "example.com"))
        )
    }

    func testEnrichmentSurvivesDeletionDuringFailedFetch() async throws {
        try await assertEnrichmentSurvivesDeletion(result: .failure(StubMetadataProvider.StubError.failed))
    }

    func testEnrichmentSkipsLinksSoftDeletedDuringSuccessAndFailure() async throws {
        let results: [Result<LinkMetadata, Error>] = [
            .success(LinkMetadata(title: "Loaded", domain: "example.com")),
            .failure(StubMetadataProvider.StubError.failed)
        ]
        for result in results {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let bookmark = try makeBookmark(in: container)
            let modifiedAt = bookmark.modifiedAt
            let provider = ActionMetadataProvider {
                bookmark.deletedAt = Date()
                try container.mainContext.save()
                return try result.get()
            }

            try await MetadataEnricher(context: container.mainContext, provider: provider)
                .enrichPending(limit: 20)

            XCTAssertNotNil(bookmark.deletedAt)
            XCTAssertEqual(bookmark.metadataState, .pending)
            XCTAssertTrue(bookmark.title.isEmpty)
            XCTAssertNil(bookmark.lastMetadataRefreshAt)
            XCTAssertEqual(bookmark.modifiedAt, modifiedAt)
            XCTAssertFalse(container.mainContext.hasChanges)
        }
    }

    func testRefreshSkipsDetachedAndUnsavedDeletedLinks() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let deleted = try makeBookmark(in: container)
        let detached = Bookmark(urlString: "https://example.com", normalizedURLString: "https://example.com")
        container.mainContext.delete(deleted)
        let provider = StubMetadataProvider(results: Array(
            repeating: .success(LinkMetadata(domain: "example.com")), count: 2
        ))
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.refresh(detached)
        try await enricher.refresh(deleted)

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(detached.metadataState, .pending)
        XCTAssertNil(detached.lastMetadataRefreshAt)
        XCTAssertTrue(container.mainContext.hasChanges, "Refresh must not save the pending deletion")
    }

    func testPendingEnrichmentSavesEachResultBeforeTheNextFetch() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        _ = try makeBookmark(in: container, path: "one")
        _ = try makeBookmark(in: container, path: "two")
        var calls = 0
        let provider = ActionMetadataProvider {
            XCTAssertFalse(container.mainContext.hasChanges, "The previous result must already be saved")
            let stored = try ModelContext(container).fetch(FetchDescriptor<Bookmark>())
            XCTAssertEqual(stored.filter { $0.metadataState == .ready }.count, calls)
            calls += 1
            return LinkMetadata(title: "Loaded", domain: "example.com")
        }

        try await MetadataEnricher(context: container.mainContext, provider: provider)
            .enrichPending(limit: 20)

        XCTAssertEqual(calls, 2)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testProviderCancellationLeavesLinkPending() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let bookmark = try makeBookmark(in: container)
        let provider = ActionMetadataProvider { throw CancellationError() }

        do {
            try await MetadataEnricher(context: container.mainContext, provider: provider)
                .enrichPending(limit: 20)
            XCTFail("Cancellation must propagate")
        } catch is CancellationError {}

        XCTAssertEqual(bookmark.metadataState, .pending)
        XCTAssertNil(bookmark.lastMetadataRefreshAt)
        XCTAssertFalse(container.mainContext.hasChanges)
    }

    func testCancelledFetchIgnoresSuccessAndFailureAndCanRestart() async throws {
        let results: [Result<LinkMetadata, Error>] = [
            .success(LinkMetadata(title: "Cancelled result", domain: "example.com")),
            .failure(StubMetadataProvider.StubError.failed)
        ]
        for result in results {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let first = try makeBookmark(in: container, path: "one")
            let second = try makeBookmark(in: container, path: "two")
            let provider = SuspendedMetadataProvider()
            let enricher = MetadataEnricher(context: container.mainContext, provider: provider)
            let task = Task { try await enricher.enrichPending(limit: 20) }
            await provider.waitUntilRequested()

            task.cancel()
            await provider.resolve(result)
            do {
                try await task.value
                XCTFail("Cancellation must stop the batch")
            } catch is CancellationError {}

            let callCount = await provider.callCount
            XCTAssertEqual(callCount, 1)
            for bookmark in [first, second] {
                XCTAssertEqual(bookmark.metadataState, .pending)
                XCTAssertNil(bookmark.lastMetadataRefreshAt)
                XCTAssertTrue(bookmark.title.isEmpty)
            }
            XCTAssertFalse(container.mainContext.hasChanges)

            let restartedProvider = StubMetadataProvider(results: Array(
                repeating: .success(LinkMetadata(title: "Restarted", domain: "example.com")), count: 2
            ))
            try await MetadataEnricher(context: container.mainContext, provider: restartedProvider)
                .enrichPending(limit: 20)
            XCTAssertEqual(first.metadataState, .ready)
            XCTAssertEqual(second.metadataState, .ready)
        }
    }

    func testEnrichmentSkipsImageBookmarks() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let image = try BookmarkRepository(context: container.mainContext)
            .saveImage(data: Data([0x01]), title: "Screenshot")
        image.metadataState = .pending
        try container.mainContext.save()
        let provider = FailingIfCalledProvider()
        let enricher = MetadataEnricher(context: container.mainContext, provider: provider)

        try await enricher.enrichPending(limit: 10)
        try await enricher.refresh(image)

        XCTAssertEqual(image.metadataState, .pending)
    }

    private struct FailingIfCalledProvider: MetadataProviding {
        func metadata(for url: URL) async throws -> LinkMetadata {
            XCTFail("Image bookmarks must not be enriched")
            return LinkMetadata(domain: "")
        }
    }

    private func assertEnrichmentSurvivesDeletion(result: Result<LinkMetadata, Error>) async throws {
        for savesDeletion in [true, false] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            let bookmark = try makeBookmark(in: container, path: "one")
            let queued = try makeBookmark(in: container, path: "two")
            let provider = ActionMetadataProvider {
                context.delete(bookmark)
                context.delete(queued)
                if savesDeletion { try context.save() }
                return try result.get()
            }

            try await MetadataEnricher(context: context, provider: provider).enrichPending(limit: 20)

            XCTAssertEqual(provider.callCount, 1, "The deleted queued link must be skipped before reading it")
            if savesDeletion {
                XCTAssertFalse(context.hasChanges)
            } else {
                XCTAssertTrue(bookmark.isDeleted)
                XCTAssertTrue(bookmark.modelContext === context)
                XCTAssertTrue(context.hasChanges, "Discarded metadata must not save pending deletions")
                try context.save()
            }
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 0)
        }
    }

    private func makeBookmark(
        in container: ModelContainer,
        path: String = "article"
    ) throws -> Bookmark {
        let bookmark = Bookmark(
            urlString: "https://example.com/\(path)",
            normalizedURLString: "https://example.com/\(path)"
        )
        bookmark.metadataState = .pending
        container.mainContext.insert(bookmark)
        try container.mainContext.save()
        return bookmark
    }
}

private actor StubMetadataProvider: MetadataProviding {
    enum StubError: Error {
        case failed
    }

    private var results: [Result<LinkMetadata, StubError>]
    private(set) var callCount = 0

    init(results: [Result<LinkMetadata, StubError>]) {
        self.results = results
    }

    func metadata(for url: URL) async throws -> LinkMetadata {
        callCount += 1
        return try results.removeFirst().get()
    }
}

@MainActor
private final class ActionMetadataProvider: MetadataProviding {
    private(set) var callCount = 0
    let action: () throws -> LinkMetadata

    init(action: @escaping () throws -> LinkMetadata) {
        self.action = action
    }

    func metadata(for url: URL) async throws -> LinkMetadata {
        callCount += 1
        return try action()
    }
}

private actor SuspendedMetadataProvider: MetadataProviding {
    private var pending: CheckedContinuation<LinkMetadata, Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    func metadata(for url: URL) async throws -> LinkMetadata {
        callCount += 1
        guard callCount == 1 else {
            XCTFail("Cancellation must stop before another fetch")
            return LinkMetadata(domain: "example.com")
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilRequested() async {
        guard pending == nil else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resolve(_ result: Result<LinkMetadata, Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}
