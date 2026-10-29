import XCTest

#if os(iOS)
@MainActor
final class AccessibilityLayoutTests: XCTestCase {
    func testLargestTextUsesReadableCardsAndReachableSnippetControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let card = app.buttons["bookmark.22222222-2222-2222-2222-222222222222"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(card.frame.width, app.frame.width * 0.8)
        let grid = XCTAttachment(screenshot: app.screenshot())
        grid.name = "Largest text populated grid"
        grid.lifetime = .keepAlways
        add(grid)
        card.tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertTrue(app.buttons["Save"].isHittable)
        let editor = XCTAttachment(screenshot: app.screenshot())
        editor.name = "Largest text snippet editor"
        editor.lifetime = .keepAlways
        add(editor)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 3))
    }

    func testLargestTextDarkLinkEditorAndSettingsRemainReachable() {
        // iOS ignores an -AppleInterfaceStyle launch argument. Set the
        // simulator's appearance, and restore it for the next test.
        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        device.appearance = .dark
        addTeardownBlock { @MainActor in device.appearance = originalAppearance }
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        // Submit so the keyboard closes; at this size the context menu's
        // lower items otherwise sit under it.
        search.typeText("Seeded Active\n")
        let card = app.buttons["bookmark.seeded-active"]
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.press(forDuration: 1)
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        XCTAssertTrue(app.buttons["Save"].isHittable)
        let editor = XCTAttachment(screenshot: app.screenshot())
        editor.name = "Largest text dark link editor"
        editor.lifetime = .keepAlways
        add(editor)
        app.buttons["Cancel"].tap()
        // Search mode hides Add. Relaunch the disposable library for Settings.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Add"].waitForExistence(timeout: 5))
        app.buttons["Add"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.importLinks"].waitForExistence(timeout: 3))
        let settings = XCTAttachment(screenshot: app.screenshot())
        settings.name = "Largest text dark Settings"
        settings.lifetime = .keepAlways
        add(settings)
        XCTAssertTrue(app.buttons["Done"].isHittable)
        app.buttons["Done"].tap()
    }

}
#endif
