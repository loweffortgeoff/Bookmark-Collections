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
