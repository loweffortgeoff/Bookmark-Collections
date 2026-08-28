import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class SnippetRepositoryTests: XCTestCase {
    func testDerivedTitleUsesTheFirstLineWithContent() {
        let derived = BookmarkRepository.deriveSnippetTitle(
            "",
            body: "\n\n   \nThe first real line\nA second line"
        )

        XCTAssertEqual(derived, "The first real line")
    }

    func testDerivedTitleTruncatesAtEightyCharacters() {
        let longLine = String(repeating: "a", count: 100)

        let derived = BookmarkRepository.deriveSnippetTitle("", body: longLine)

        XCTAssertEqual(derived, String(repeating: "a", count: 80) + "…")
    }

    func testDerivedTitleFallsBackToSnippetForWhitespaceOnlyBodies() {
        XCTAssertEqual(BookmarkRepository.deriveSnippetTitle("", body: "   \n\t\n "), "Snippet")
    }

    func testSuppliedTitleWinsOverDerivation() {
        XCTAssertEqual(
            BookmarkRepository.deriveSnippetTitle("  Chosen Title  ", body: "Ignored first line"),
            "Chosen Title"
        )
    }

    func testSaveSnippetStoresBodyAndKeepsNormalizedURLEmpty() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(body: "Remember this paragraph.")

        XCTAssertEqual(snippet.kind, .text)
        XCTAssertEqual(snippet.snippetBody, "Remember this paragraph.")
        XCTAssertEqual(snippet.title, "Remember this paragraph.")
        XCTAssertEqual(snippet.normalizedURLString, "")
        XCTAssertEqual(snippet.urlString, "")
        XCTAssertEqual(snippet.domain, "")
        XCTAssertEqual(snippet.metadataState, .ready)
    }

    func testSaveSnippetRecordsAParseableSourceLink() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(
            body: "A quote worth keeping.",
            sourceURL: "https://Example.com/article#intro"
        )

        XCTAssertEqual(snippet.urlString, "https://Example.com/article#intro")
        XCTAssertEqual(snippet.domain, "example.com")
        XCTAssertEqual(snippet.normalizedURLString, "")
    }

    func testSaveSnippetDropsAnUnparseableSourceLinkRatherThanFailing() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let snippet = try repository.saveSnippet(body: "Keep the text.", sourceURL: "not a URL")

        XCTAssertEqual(snippet.snippetBody, "Keep the text.")
        XCTAssertEqual(snippet.urlString, "")
        XCTAssertEqual(snippet.domain, "")
    }

    func testSaveSnippetRejectsAnEmptyBody() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        XCTAssertThrowsError(try repository.saveSnippet(body: "   \n  "))
    }

    func testIdenticalSnippetsBothPersist() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)

        let first = try repository.saveSnippet(body: "Same text")
        let second = try repository.saveSnippet(body: "Same text")

        XCTAssertNotEqual(first.id, second.id)
        let all = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(all.count, 2)
    }

    func testReconcileDuplicatesLeavesSnippetsAlone() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        _ = try repository.saveSnippet(body: "Same text")
        _ = try repository.saveSnippet(body: "Same text")

        try repository.reconcileDuplicates()

        let all = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(all.count, 2)
    }

    func testUpdateSnippetRederivesTheTitleWhenTheTitleIsCleared() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let snippet = try repository.saveSnippet(title: "Original", body: "First body")

        try repository.updateSnippet(snippet, title: "", body: "Replacement body", sourceURL: nil)

        XCTAssertEqual(snippet.snippetBody, "Replacement body")
        XCTAssertEqual(snippet.title, "Replacement body")
    }

    func testUpdateSnippetRejectsAnEmptyBody() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext)
        let snippet = try repository.saveSnippet(body: "Original body")

        XCTAssertThrowsError(
            try repository.updateSnippet(snippet, title: "", body: "  ", sourceURL: nil)
        )
        XCTAssertEqual(snippet.snippetBody, "Original body")
    }
}
