import XCTest
@testable import BookmarkCollections

@MainActor
final class ClipboardURLAssistTests: XCTestCase {
    func testValidWebURLAcceptsHTTPAndHTTPSAndSchemelessDomains() {
        XCTAssertEqual(ClipboardURLAssist.validWebURL(from: "https://example.com/a"), "https://example.com/a")
        XCTAssertEqual(ClipboardURLAssist.validWebURL(from: "  http://example.com  "), "http://example.com")
        XCTAssertEqual(ClipboardURLAssist.validWebURL(from: "example.com/page"), "https://example.com/page")
    }

    func testValidWebURLRejectsProseContainingURLSnippetsEmailsAndNonWebSchemes() {
        let rejected: [String?] = [
            "Check out https://example.com today",
            "Just a note",
            "line 1\nline 2",
            "https://example.com/a\nhttps://example.com/b",
            "user@example.com",
            "mailto:a@b.com",
            "file:///tmp/x",
            "",
            "   ",
            nil
        ]
        for value in rejected {
            XCTAssertNil(ClipboardURLAssist.validWebURL(from: value), String(describing: value))
        }
    }

    func testClipboardAssistSuppressedUnderUITesting() async {
        #if os(macOS)
        let url = await ClipboardURLAssist.currentClipboardURL(isUITesting: true)
        XCTAssertNil(url)
        #else
        let hasURL = await ClipboardURLAssist.clipboardHasProbableWebURL(isUITesting: true)
        XCTAssertFalse(hasURL)
        XCTAssertNil(ClipboardURLAssist.readClipboardURLForExplicitAction(isUITesting: true))
        #endif
    }

    func testMenuBarRouterConsumeDropsRequestWhenBlockedAndDeliversWhenUnblocked() {
        let router = MenuBarRouter()

        router.request(.saveFromClipboard)
        XCTAssertNil(router.consume(blocked: true))
        XCTAssertNil(router.consume(blocked: false), "A blocked request is dropped, not kept.")

        router.request(.saveFromClipboard)
        XCTAssertEqual(router.consume(blocked: false), .saveFromClipboard)
        XCTAssertNil(router.consume(blocked: false))
    }
}
