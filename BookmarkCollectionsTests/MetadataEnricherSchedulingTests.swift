import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class MetadataEnricherSchedulingTests: XCTestCase {
    func testKeyedPendingEnrichmentDrainsClonesOneAtATimeWithoutRetryingFailures() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let first = try makeBookmark(in: context, path: "clone")
        let clone = try makeBookmark(in: context, path: "clone")
        clone.id = first.id
        clone.createdAt = first.createdAt
        let failed = try makeBookmark(in: context, path: "failed")
        failed.metadataState = .failed
        try context.save()
        let provider = RecordingMetadataProvider()
        let enricher = MetadataEnricher(context: context, provider: provider)
        let initialQueue = try pendingLinks(in: context)
        let firstID = try XCTUnwrap(initialQueue.first?.persistentModelID)
        let secondID = try XCTUnwrap(initialQueue.last?.persistentModelID)
        XCTAssertNotEqual(firstID, secondID, "Clone UUIDs must not be used as task keys")

        try await enricher.enrichPendingBookmark(id: firstID)

        let remaining = try pendingLinks(in: context)
        XCTAssertEqual(remaining.map(\.persistentModelID), [secondID])
        XCTAssertEqual(failed.metadataState, .failed)
        XCTAssertNil(failed.lastMetadataRefreshAt)
        let firstRequests = await provider.requestedURLs
        XCTAssertEqual(firstRequests, [URL(string: first.urlString)!])
        XCTAssertFalse(context.hasChanges)

        try await enricher.enrichPendingBookmark(id: secondID)

        XCTAssertTrue(try pendingLinks(in: context).isEmpty)
        XCTAssertEqual(first.metadataState, .ready)
        XCTAssertEqual(clone.metadataState, .ready)
        XCTAssertEqual(failed.metadataState, .failed)
        let allRequests = await provider.requestedURLs
        XCTAssertEqual(allRequests.count, 2)
    }

    func testKeyedPendingEnrichmentSkipsIneligibleOrMissingRecordWithoutSubstitution() async throws {
        for change in ["ready", "failed", "soft-deleted", "image", "hard-deleted"] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            let keyed = try makeBookmark(in: context, path: "keyed")
            let other = try makeBookmark(in: context, path: "other")
            let keyedID = keyed.persistentModelID
            switch change {
            case "ready": keyed.metadataState = .ready
            case "failed": keyed.metadataState = .failed
            case "soft-deleted": keyed.deletedAt = Date()
            case "image": keyed.kind = .image
            default: context.delete(keyed)
            }
            try context.save()
            let provider = RecordingMetadataProvider()

            try await MetadataEnricher(context: context, provider: provider)
                .enrichPendingBookmark(id: keyedID)

            let requests = await provider.requestedURLs
            XCTAssertTrue(requests.isEmpty, change)
            XCTAssertEqual(other.metadataState, .pending, change)
            XCTAssertNil(other.lastMetadataRefreshAt, change)
            XCTAssertFalse(context.hasChanges, change)
        }
    }

    func testPendingKeyChangesForSameCountReplacement() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let first = try makeBookmark(in: context, path: "first")
        let second = try makeBookmark(in: context, path: "second")
        let initialQueue = try pendingLinks(in: context)
        XCTAssertEqual(initialQueue.first?.persistentModelID, first.persistentModelID)
        let provider = RecordingMetadataProvider()

        try await MetadataEnricher(context: context, provider: provider)
            .enrichPendingBookmark(id: first.persistentModelID)
        _ = try makeBookmark(in: context, path: "replacement")

        let nextQueue = try pendingLinks(in: context)
        XCTAssertEqual(nextQueue.count, initialQueue.count)
        XCTAssertEqual(nextQueue.first?.persistentModelID, second.persistentModelID)
        XCTAssertNotEqual(nextQueue.first?.persistentModelID, initialQueue.first?.persistentModelID)
        let requests = await provider.requestedURLs
        XCTAssertEqual(requests, [URL(string: first.urlString)!])
    }

    func testKeyedEnrichmentHonorsCapturedIDWhenAnOlderLinkArrives() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let keyed = try makeBookmark(in: context, path: "keyed")
        let capturedID = keyed.persistentModelID
        let older = try makeBookmark(in: context, path: "older")
        older.createdAt = Date(timeIntervalSince1970: 1)
        try context.save()
        XCTAssertEqual(try pendingLinks(in: context).first?.persistentModelID, older.persistentModelID)
        let provider = RecordingMetadataProvider()

        try await MetadataEnricher(context: context, provider: provider)
            .enrichPendingBookmark(id: capturedID)

        let requests = await provider.requestedURLs
        XCTAssertEqual(requests, [URL(string: keyed.urlString)!])
        XCTAssertEqual(keyed.metadataState, .ready)
        XCTAssertEqual(older.metadataState, .pending)
    }

    func testDefaultBatchStillFetchesPendingBeforeDueFailures() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let failed = try makeBookmark(in: context, path: "failed")
        failed.metadataState = .failed
        let pending = try makeBookmark(in: context, path: "pending")
        try context.save()
        let provider = RecordingMetadataProvider()

        try await MetadataEnricher(context: context, provider: provider).enrichPending(limit: 2)

        let requests = await provider.requestedURLs
        XCTAssertEqual(requests.map(\.absoluteString), [pending.urlString, failed.urlString])
        XCTAssertEqual(pending.metadataState, .ready)
        XCTAssertEqual(failed.metadataState, .ready)
    }

    func testActivationRetriesOnlyDueFailedLinksUpToLimit() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let pending = try makeBookmark(in: context, path: "pending")
        let freshFailure = try makeBookmark(in: context, path: "fresh")
        freshFailure.metadataState = .failed
        freshFailure.lastMetadataRefreshAt = Date()
        let deletedFailure = try makeBookmark(in: context, path: "deleted")
        deletedFailure.metadataState = .failed
        deletedFailure.deletedAt = Date()
        var due: [Bookmark] = []
        for index in 0..<21 {
            let bookmark = try makeBookmark(in: context, path: "due-\(index)")
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = Date(
                timeIntervalSinceNow: -(MetadataEnricher.failedRetryInterval + 60)
            )
            due.append(bookmark)
        }
        try context.save()
        let provider = RecordingMetadataProvider()

        try await MetadataEnricher(context: context, provider: provider)
            .enrichPending(limit: 20, includePending: false)

        let requests = await provider.requestedURLs
        XCTAssertEqual(requests.count, 20)
        XCTAssertEqual(Set(requests.map(\.absoluteString)), Set(due.prefix(20).map(\.urlString)))
        XCTAssertEqual(due.filter { $0.metadataState == .ready }.count, 20)
        XCTAssertEqual(due.last?.metadataState, .failed)
        XCTAssertEqual(pending.metadataState, .pending)
        XCTAssertNil(pending.lastMetadataRefreshAt)
        XCTAssertEqual(freshFailure.metadataState, .failed)
        XCTAssertEqual(deletedFailure.metadataState, .failed)
        XCTAssertNil(deletedFailure.lastMetadataRefreshAt)
        XCTAssertFalse(context.hasChanges)
    }

    func testPendingAndActivationTasksSelectDifferentRecords() async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let pending = try makeBookmark(in: context, path: "pending")
        let failed = try makeBookmark(in: context, path: "failed")
        failed.metadataState = .failed
        try context.save()
        let pendingProvider = ControlledMetadataProvider()
        let retryProvider = RecordingMetadataProvider()
        let task = Task {
            try await MetadataEnricher(context: context, provider: pendingProvider)
                .enrichPendingBookmark(id: pending.persistentModelID)
        }
        await pendingProvider.waitUntilRequested()

        try await MetadataEnricher(context: context, provider: retryProvider)
            .enrichPending(limit: 20, includePending: false)

        let retryRequests = await retryProvider.requestedURLs
        XCTAssertEqual(retryRequests, [URL(string: failed.urlString)!])
        XCTAssertEqual(pending.metadataState, .pending)
        XCTAssertEqual(failed.metadataState, .ready)
        await pendingProvider.resolve(.success(LinkMetadata(domain: "example.com")))
        try await task.value
        XCTAssertEqual(pending.metadataState, .ready)
        let pendingCalls = await pendingProvider.callCount
        XCTAssertEqual(pendingCalls, 1)
    }

    func testLateSuccessDoesNotOverwriteAnotherEnrichersSavedResult() async throws {
        try await assertLateResultIsDiscarded(.success(LinkMetadata(
            title: "Stale title", domain: "stale.example.com",
            faviconData: Data([8]), previewImageData: Data([9])
        )))
    }

    func testLateFailureDoesNotOverwriteAnotherEnrichersSavedResult() async throws {
        try await assertLateResultIsDiscarded(.failure(ProviderError.failed))
    }

    func testEnrichmentSurvivesSecondContextDeletionDuringSuccess() async throws {
        try await assertSecondContextDeletionDiscardsResult(.success(LinkMetadata(
            title: "Deleted result", domain: "deleted.example.com", previewImageData: Data([9])
        )))
    }

    func testEnrichmentSurvivesSecondContextDeletionDuringFailure() async throws {
        try await assertSecondContextDeletionDiscardsResult(.failure(ProviderError.failed))
    }

    func testURLChangeDiscardsOldSuccessAndFailureAndChangesTaskKey() async throws {
        for result: Result<LinkMetadata, Error> in [
            .success(LinkMetadata(title: "Old page", domain: "old.example", previewImageData: Data([9]))),
            .failure(ProviderError.failed)
        ] {
            let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
            let context = container.mainContext
            context.autosaveEnabled = false
            let bookmark = try makeBookmark(in: context)
            let previousKey = PendingMetadataRequest(id: bookmark.persistentModelID, urlString: bookmark.urlString)
            let provider = ControlledMetadataProvider()
            let task = Task {
                try await MetadataEnricher(context: context, provider: provider).refresh(bookmark)
            }
            await provider.waitUntilRequested()
            bookmark.urlString = "https://new.example/article"
            bookmark.normalizedURLString = bookmark.urlString
            try context.save()
            let nextKey = PendingMetadataRequest(id: bookmark.persistentModelID, urlString: bookmark.urlString)
            XCTAssertNotEqual(previousKey, nextKey, "A URL edit must restart the pending task")
            await provider.resolve(result)
            try await task.value
            XCTAssertEqual(bookmark.metadataState, .pending)
            XCTAssertTrue(bookmark.title.isEmpty)
            XCTAssertNil(bookmark.previewImageData)
            XCTAssertNil(bookmark.lastMetadataRefreshAt)
            XCTAssertFalse(context.hasChanges)

            let replacement = RecordingMetadataProvider()
            try await MetadataEnricher(context: context, provider: replacement)
                .enrichPendingBookmark(id: nextKey.id)
            let requests = await replacement.requestedURLs
            XCTAssertEqual(requests, [URL(string: nextKey.urlString)!])
            XCTAssertEqual(bookmark.metadataState, .ready)
        }
    }

    private func assertLateResultIsDiscarded(_ result: Result<LinkMetadata, Error>) async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        context.autosaveEnabled = false
        let bookmark = try makeBookmark(in: context)
        bookmark.lastMetadataRefreshAt = Date(timeIntervalSince1970: 1)
        try context.save()
        let firstProvider = ControlledMetadataProvider()
        let secondProvider = ControlledMetadataProvider()
        let first = Task {
            try await MetadataEnricher(context: context, provider: firstProvider).refresh(bookmark)
        }
        await firstProvider.waitUntilRequested()
        let second = Task {
            try await MetadataEnricher(context: context, provider: secondProvider).refresh(bookmark)
        }
        await secondProvider.waitUntilRequested()

        await firstProvider.resolve(.success(LinkMetadata(
            title: "Saved title", domain: "saved.example.com",
            faviconData: Data([1]), previewImageData: Data([2])
        )))
        try await first.value
        let savedRefreshAt = try XCTUnwrap(bookmark.lastMetadataRefreshAt)
        let savedModifiedAt = bookmark.modifiedAt
        bookmark.isFavorite = true

        await secondProvider.resolve(result)
        try await second.value

        XCTAssertEqual(bookmark.metadataState, .ready)
        XCTAssertEqual(bookmark.title, "Saved title")
        XCTAssertEqual(bookmark.domain, "saved.example.com")
        XCTAssertEqual(bookmark.faviconData, Data([1]))
        XCTAssertEqual(bookmark.previewImageData, Data([2]))
        XCTAssertEqual(bookmark.lastMetadataRefreshAt, savedRefreshAt)
        XCTAssertEqual(bookmark.modifiedAt, savedModifiedAt)
        XCTAssertTrue(context.hasChanges, "Discarding a stale result must not save unrelated edits")
        let saved = try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Bookmark>()).first)
        XCTAssertFalse(saved.isFavorite)
        let firstCount = await firstProvider.callCount
        let secondCount = await secondProvider.callCount
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 1)
    }

    private func assertSecondContextDeletionDiscardsResult(
        _ result: Result<LinkMetadata, Error>
    ) async throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        context.autosaveEnabled = false
        let bookmark = try makeBookmark(in: context)
        let provider = ControlledMetadataProvider()
        let task = Task {
            try await MetadataEnricher(context: context, provider: provider).enrichPending(limit: 20)
        }
        await provider.waitUntilRequested()

        let deletingContext = ModelContext(container)
        let stored = try XCTUnwrap(deletingContext.fetch(FetchDescriptor<Bookmark>()).first)
        deletingContext.delete(stored)
        try deletingContext.save()
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Bookmark>()), 0)
        let bookmarkID = bookmark.persistentModelID
        let descriptor = FetchDescriptor<Bookmark>(predicate: #Predicate { $0.persistentModelID == bookmarkID })
        XCTAssertEqual(try context.fetchCount(descriptor), 0,
                       "An explicit existence check must see the saved second-context deletion")

        await provider.resolve(result)
        try await task.value

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 1)
        if bookmark.modelContext != nil && !bookmark.isDeleted {
            XCTAssertEqual(bookmark.metadataState, .pending, "Do not write metadata into a stale registered model")
            XCTAssertTrue(bookmark.title.isEmpty)
            XCTAssertNil(bookmark.lastMetadataRefreshAt)
        }
        XCTAssertFalse(context.hasChanges, "A result for a record deleted in another context must not write")
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Bookmark>()), 0)
    }

    private func pendingLinks(in context: ModelContext) throws -> [Bookmark] {
        try context.fetch(FetchDescriptor<Bookmark>(sortBy: [
            SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)
        ])).filter(MetadataEnricher.isActivePendingLink)
    }

    private func makeBookmark(in context: ModelContext, path: String = "article") throws -> Bookmark {
        let bookmark = Bookmark(
            urlString: "https://example.com/\(path)",
            normalizedURLString: "https://example.com/\(path)"
        )
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    private enum ProviderError: Error {
        case failed
    }
}

private actor RecordingMetadataProvider: MetadataProviding {
    private(set) var requestedURLs: [URL] = []

    func metadata(for url: URL) async throws -> LinkMetadata {
        requestedURLs.append(url)
        return LinkMetadata(title: "Loaded", domain: "example.com")
    }
}

private actor ControlledMetadataProvider: MetadataProviding {
    private var pending: CheckedContinuation<LinkMetadata, Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    private(set) var callCount = 0

    func metadata(for url: URL) async throws -> LinkMetadata {
        callCount += 1
        guard callCount == 1 else {
            XCTFail("Each controlled provider expects one request")
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
