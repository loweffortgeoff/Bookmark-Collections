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

    func testUserEnteredAddsHTTPS() {
        XCTAssertEqual(NormalizedURL.userEntered("example.com"), "https://example.com")
        XCTAssertEqual(NormalizedURL.userEntered(" www.example.com/page "), "https://www.example.com/page")
        XCTAssertEqual(NormalizedURL.userEntered("example.com:8080/a"), "https://example.com:8080/a")
        XCTAssertEqual(NormalizedURL.userEntered("http://example.com"), "http://example.com")
        XCTAssertEqual(NormalizedURL.userEntered("not a url"), "not a url")
    }

    func testUserEnteredLeavesTextThatIsNotAnAddress() {
        for value in ["v1.2", "3.14", "user@example.com", "example", "example.", "a.b1"] {
            XCTAssertEqual(NormalizedURL.userEntered(value), value, value)
            XCTAssertThrowsError(try NormalizedURL(NormalizedURL.userEntered(value)), value)
        }
    }

    func testUserEnteredLeavesOtherSchemesForValidationToReject() {
        XCTAssertEqual(NormalizedURL.userEntered("mailto:a@b.com"), "mailto:a@b.com")
        XCTAssertThrowsError(try NormalizedURL(NormalizedURL.userEntered("mailto:a@b.com"))) {
            XCTAssertEqual($0 as? NormalizedURL.ValidationError, .unsupportedScheme)
        }
    }

    func testUserEnteredAddressesNormalize() throws {
        XCTAssertEqual(try NormalizedURL(NormalizedURL.userEntered("example.com")).string, "https://example.com/")
        XCTAssertEqual(
            try NormalizedURL(NormalizedURL.userEntered("www.example.com/page")).string,
            "https://www.example.com/page"
        )
    }
}
