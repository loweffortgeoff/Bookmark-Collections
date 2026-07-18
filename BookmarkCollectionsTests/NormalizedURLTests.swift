import XCTest
@testable import BookmarkCollections

final class NormalizedURLTests: XCTestCase {
    func testNormalizationRules() throws {
        let cases = [
            ("HTTPS://Example.COM:443", "https://example.com/"),
            ("http://Example.COM:80", "http://example.com/"),
            ("https://example.com/a#section", "https://example.com/a"),
            ("https://example.com/a?utm_source=x&id=7", "https://example.com/a?id=7"),
            ("https://example.com/a?fbclid=x&gclid=y", "https://example.com/a")
        ]

        for (input, expected) in cases {
            XCTAssertEqual(try NormalizedURL(input).string, expected, input)
        }
    }

    func testPreservesMeaningfulQueryItemsAndTheirOrder() throws {
        let normalized = try NormalizedURL(
            "https://example.com/search?z=last&utm_campaign=spring&q=swift&q=data"
        )

        XCTAssertEqual(
            normalized.string,
            "https://example.com/search?z=last&q=swift&q=data"
        )
    }

    func testRejectsUnsupportedOrMalformedURLs() {
        XCTAssertThrowsError(try NormalizedURL("file:///tmp/a"))
        XCTAssertThrowsError(try NormalizedURL("ftp://example.com/file"))
        XCTAssertThrowsError(try NormalizedURL("not a url"))
        XCTAssertThrowsError(try NormalizedURL("https:///missing-host"))
    }
}

