import XCTest

final class BookmarkCollectionsUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Bookmarks"].waitForExistence(timeout: 5))
    }
}

