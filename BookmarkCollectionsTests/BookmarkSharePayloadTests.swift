import XCTest
@testable import BookmarkCollections

@MainActor
final class BookmarkSharePayloadTests: XCTestCase {
    func testLinkSharesItsURL() {
        let bookmark = Bookmark(urlString: "https://example.com/path", normalizedURLString: "https://example.com/path")
        guard case let .link(url) = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Expected URL") }
        XCTAssertEqual(url.absoluteString, bookmark.urlString)
    }

    func testSnippetAppendsOnlyValidSourceOnSeparateLine() {
        let bookmark = Bookmark(urlString: "https://example.com/source", normalizedURLString: "")
        bookmark.kind = .text
        bookmark.snippetBody = "Saved prose"
        guard case let .text(text) = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Expected text") }
        XCTAssertEqual(text, "Saved prose\nhttps://example.com/source")
        bookmark.urlString = "file:///private/path"
        guard case let .text(body) = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Expected usable body") }
        XCTAssertEqual(body, "Saved prose")
    }

    func testImageSharesStoredBytesAndRejectsMissingOrCorruptImage() throws {
        let bookmark = Bookmark(urlString: "", normalizedURLString: "")
        bookmark.kind = .image
        guard case .unavailable = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Missing image needs useful error") }
        bookmark.previewImageData = Data([1, 2, 3])
        guard case let .unavailable(message) = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Corrupt image needs useful error") }
        XCTAssertTrue(message.contains("Image"))
        bookmark.previewImageData = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="))
        guard case let .image(data) = BookmarkSharePayload(bookmark: bookmark) else { return XCTFail("Expected local image") }
        XCTAssertEqual(data, bookmark.previewImageData)
    }
}
