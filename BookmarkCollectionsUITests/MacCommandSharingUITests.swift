import XCTest

#if os(macOS)
@MainActor
final class MacCommandSharingUITests: XCTestCase {
    func testImageAndSnippetOpenAndShareThroughNativeMenu() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let image = app.buttons["bookmark.11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        image.click()
        XCTAssertTrue(app.descendants(matching: .any)["imageViewer"].waitForExistence(timeout: 3))
        app.buttons["Done"].click()
        shareFromMenu(app)
        XCTAssertTrue(app.buttons["Share Image"].waitForExistence(timeout: 3))
        capture(app, "Mac image Share")
        app.buttons["Cancel"].click()

        let snippet = app.buttons["bookmark.22222222-2222-2222-2222-222222222222"]
        snippet.click()
        XCTAssertTrue(app.descendants(matching: .any)["snippet.editor"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].click()
        shareFromMenu(app)
        XCTAssertTrue(app.buttons["Share Snippet"].waitForExistence(timeout: 3))
        capture(app, "Mac snippet Share")
        app.buttons["Cancel"].click()

        let link = app.buttons["bookmark.seeded-active"]
        link.rightClick()
        app.menuItems["Get Info"].click()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))
        app.buttons["Done"].click()
        shareFromMenu(app)
        XCTAssertTrue(app.buttons["Share Bookmark"].waitForExistence(timeout: 3))
        capture(app, "Mac link Share")
        app.buttons["Cancel"].click()

        let search = app.searchFields.firstMatch
        search.click()
        search.typeText("no item can match this filter")
        app.menuBars.menuBarItems["Bookmark"].click()
        XCTAssertFalse(app.menuItems["Share"].isEnabled)
        XCTAssertFalse(app.menuItems["Open"].isEnabled)
        XCTAssertFalse(app.menuItems["Move to Recently Deleted"].isEnabled)
        app.typeKey(.escape, modifierFlags: [])
    }

    private func shareFromMenu(_ app: XCUIApplication) {
        app.menuBars.menuBarItems["Bookmark"].click()
        app.menuItems["Share"].click()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
