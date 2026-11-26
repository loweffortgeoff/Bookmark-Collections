import SwiftData
import UniformTypeIdentifiers
import XCTest
@testable import BookmarkCollections

@MainActor
final class ExistingLinkMatchTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUpWithError() throws {
        container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
    }

    private func insert(_ url: String, collection: BookmarkCollection? = nil, deleted: Bool = false) throws -> Bookmark {
        let bookmark = Bookmark(urlString: url, normalizedURLString: try NormalizedURL(url).string)
        bookmark.collection = collection
        if deleted { bookmark.deletedAt = Date() }
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    private var repository: BookmarkRepository {
        BookmarkRepository(context: context, isUnlocked: true)
    }

    func testActiveUnfiledMatchFormatsNoticeWithoutCollection() throws {
        let existing = try insert("https://example.com/post")

        let match = try XCTUnwrap(repository.existingLinkMatch(for: "https://example.com/post"))

        XCTAssertEqual(match.status, .active(savedAt: existing.createdAt, collectionName: nil))
        XCTAssertEqual(match.bookmarkPersistentID, existing.persistentModelID)
        let notice = match.noticeText(relativeTo: existing.createdAt.addingTimeInterval(3600))
        XCTAssertTrue(notice.hasPrefix("Already tucked · saved "), notice)
        XCTAssertFalse(notice.contains(" in "), notice)
    }

    func testActiveFiledMatchIncludesCollectionName() throws {
        let reading = BookmarkCollection(name: "Reading", sortPosition: 0)
        context.insert(reading)
        let existing = try insert("https://example.com/filed", collection: reading)

        let match = try XCTUnwrap(repository.existingLinkMatch(for: "https://example.com/filed"))

        XCTAssertEqual(match.status, .active(savedAt: existing.createdAt, collectionName: "Reading"))
        XCTAssertEqual(match.bookmarkPersistentID, existing.persistentModelID)
        XCTAssertTrue(match.noticeText().contains("in Reading"), match.noticeText())
    }

    func testRecentlyDeletedMatchReturnsRestoreNotice() throws {
        _ = try insert("https://example.com/gone", deleted: true)

        let match = try XCTUnwrap(repository.existingLinkMatch(for: "https://example.com/gone"))

        XCTAssertEqual(match.status, .recentlyDeleted)
        XCTAssertEqual(match.noticeText(), "In Recently Deleted · saving will restore it.")
    }

    func testTrackingParametersAndSchemelessInputMatchCanonicalURL() throws {
        let existing = try insert("https://example.com/post")

        let match = try XCTUnwrap(repository.existingLinkMatch(
            for: "example.com/post?utm_source=x#top",
            applyUserEnteredFixup: true
        ))

        XCTAssertEqual(match.bookmarkPersistentID, existing.persistentModelID)
    }

    func testInvalidOrUnmatchedURLReturnsNil() throws {
        _ = try insert("https://example.com/post")

        XCTAssertNil(try repository.existingLinkMatch(for: "not a url", applyUserEnteredFixup: true))
        XCTAssertNil(try repository.existingLinkMatch(for: "mailto:a@b.com"))
        XCTAssertNil(try repository.existingLinkMatch(for: "https://unseen.example"))
        XCTAssertNil(try repository.existingLinkMatch(for: ""))
    }

    func testShareCaptureModelPopulatesAndResetsExistingMatch() async throws {
        _ = try insert("https://example.com/active")
        _ = try insert("https://example.com/deleted", deleted: true)
        let model = ShareCaptureModel(context: context, onComplete: {})

        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/active")!)])
        guard case .active = model.existingMatch?.status else {
            return XCTFail("Expected an active match, got \(String(describing: model.existingMatch))")
        }

        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/deleted")!)])
        XCTAssertEqual(model.existingMatch?.status, .recentlyDeleted)

        await model.load(from: [NSItemProvider(object: NSURL(string: "https://example.com/new")!)])
        XCTAssertNil(model.existingMatch)

        await model.load(from: [NSItemProvider(object: "Some highlighted text" as NSString)])
        XCTAssertNil(model.existingMatch)
    }
}
