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
