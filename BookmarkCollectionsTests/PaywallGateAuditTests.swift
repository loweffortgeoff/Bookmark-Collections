import SwiftData
import XCTest
@testable import BookmarkCollections

/// Release audit: use real repositories with disposable, in-memory stores.
@MainActor
final class PaywallGateAuditTests: XCTestCase {
    private func store(_ count: Int = 10) throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: true)
        for index in 0..<count {
            _ = try repository.save(url: "https://audit.example/\(index)")
        }
        return container
    }

    private func activeCount(_ container: ModelContainer) throws -> Int {
        try container.mainContext.fetch(FetchDescriptor<Bookmark>()).filter { $0.deletedAt == nil }.count
    }

    private func locked(_ container: ModelContainer) -> BookmarkRepository {
        BookmarkRepository(context: container.mainContext, isUnlocked: false, paywallEnabled: true)
    }

    private func assertLimit(_ action: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try action(), file: file, line: line) {
            XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached, file: file, line: line)
        }
    }

    func testMixedKindsShareOneTenItemCap() throws {
        let container = try store(8)
        let repository = locked(container)
        _ = try repository.saveImage(data: Data([1]), title: "Image")
        _ = try repository.saveSnippet(body: "Snippet")
        assertLimit { _ = try repository.save(url: "https://audit.example/eleven") }
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testImageCreationIsBlockedWithoutInsertingAtLimit() throws {
        let container = try store()
        assertLimit { _ = try locked(container).saveImage(data: Data([1]), title: "Image") }
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testSnippetCreationIsBlockedWithoutInsertingAtLimit() throws {
        let container = try store()
        assertLimit { _ = try locked(container).saveSnippet(body: "Snippet") }
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testDeletingFreesExactlyOneSlot() throws {
        let container = try store()
        let repository = locked(container)
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        try repository.softDelete(first)
        _ = try repository.saveSnippet(body: "Replacement")
        assertLimit { _ = try repository.saveSnippet(body: "One too many") }
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testRestoreAtLimitKeepsDeletedItemDeleted() throws {
        let container = try store(11)
        let repository = locked(container)
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        try repository.softDelete(first)
        assertLimit { try repository.restore(first) }
        XCTAssertNotNil(first.deletedAt)
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testResavingDeletedURLAtLimitDoesNotRestoreIt() throws {
        let container = try store(11)
        let repository = locked(container)
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        try repository.softDelete(first)
        assertLimit { _ = try repository.save(url: first.urlString) }
        XCTAssertNotNil(first.deletedAt)
    }

    func testRestoringBelowLimitConsumesOneSlot() throws {
        let container = try store()
        let repository = locked(container)
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        try repository.softDelete(first)
        try repository.restore(first)
        XCTAssertNil(first.deletedAt)
        assertLimit { _ = try repository.saveSnippet(body: "Eleven") }
    }

    func testExistingLibraryAboveLimitRemainsEditableAndExportable() throws {
        let container = try store(12)
        let repository = locked(container)
        let first = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Bookmark>()).first)
        try repository.setFavorite(first, to: true)
        try repository.markOpened(first)
        _ = try repository.save(url: first.urlString, favorite: true)
        XCTAssertTrue(first.isFavorite)
        XCTAssertFalse(try LibraryExportService(context: container.mainContext).exportJSON().isEmpty)
        XCTAssertFalse(try LibraryExportService(context: container.mainContext).exportHTML().isEmpty)
        assertLimit { _ = try repository.saveSnippet(body: "Over limit") }
        XCTAssertEqual(try activeCount(container), 12)
    }

    func testUnlockedAllowsAllKindsBeyondTen() throws {
        let container = try store()
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: true, paywallEnabled: true)
        _ = try repository.save(url: "https://audit.example/extra")
        _ = try repository.saveImage(data: Data([1]), title: "Image")
        _ = try repository.saveSnippet(body: "Snippet")
        XCTAssertEqual(try activeCount(container), 13)
    }

    func testBetaBypassAllowsAllKindsWithoutPurchase() throws {
        let container = try store()
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: false, paywallEnabled: false)
        _ = try repository.save(url: "https://audit.example/extra")
        _ = try repository.saveImage(data: Data([1]), title: "Image")
        _ = try repository.saveSnippet(body: "Snippet")
        XCTAssertEqual(try activeCount(container), 13)
    }

    func testEditingExistingSnippetAtLimitRemainsFree() throws {
        let container = try store(9)
        let repository = locked(container)
        let snippet = try repository.saveSnippet(body: "Before")
        try repository.updateSnippet(snippet, title: "After", body: "Updated", sourceURL: nil, collection: nil, isFavorite: true)
        XCTAssertEqual(snippet.snippetBody, "Updated")
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testShareAtLimitDoesNotCompleteOrInsert() async throws {
        let container = try store()
        var completed = false
        let model = ShareCaptureModel(collections: [], saveAction: { capture, _, _ in
            try self.locked(container).save(url: capture.urlString)
        }, onComplete: { completed = true })
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: "https://audit.example/share")!)])
        guard case let .failed(message) = model.state else { return XCTFail("Expected limit failure") }
        XCTAssertTrue(message.contains("Open Tucked"))
        XCTAssertFalse(completed)
        XCTAssertEqual(try activeCount(container), 10)
    }

    func testShareExistingLinkAtLimitStillCompletes() async throws {
        let container = try store()
        var completed = false
        let model = ShareCaptureModel(collections: [], saveAction: { capture, _, _ in
            try self.locked(container).save(url: capture.urlString)
        }, onComplete: { completed = true })
        await model.quickSave(from: [NSItemProvider(object: NSURL(string: "https://audit.example/0")!)])
        XCTAssertTrue(completed)
        XCTAssertEqual(try activeCount(container), 10)
    }
}
