import XCTest
@testable import BookmarkCollections

final class AboutLinksTests: XCTestCase {
    func testAboutLinksPointAtTheLiveLowEffortAppsPages() {
        XCTAssertEqual(
            AboutLink.allCases.map(\.url.absoluteString),
            [
                "https://www.loweffortapps.app/privacy/",
                "https://www.loweffortapps.app/support/",
                "https://www.loweffortapps.app/",
            ]
        )
        XCTAssertEqual(
            AboutLink.allCases.map(\.title),
            ["Privacy Policy", "Support", "Low Effort Apps"]
        )
    }
}
