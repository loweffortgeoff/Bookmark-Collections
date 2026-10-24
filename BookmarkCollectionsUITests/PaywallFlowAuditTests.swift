import XCTest
import StoreKitTest

@MainActor
final class PaywallFlowAuditTests: XCTestCase {
    private var application: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        application = XCUIApplication()
        #if os(macOS)
        application.launchArguments = ["-ui-testing"]
        #else
        application.launchArguments = ["-ui-testing", "-free-limit", "0"]
        #endif
        // Start locked on both platforms. A Mac that owns Tucked would
        // otherwise read its real shared unlock flag and skip the paywall.
        application.launchArguments += ["-tuckedProUnlocked", "NO"]
        application.launch()
    }

    private func launch() -> XCUIApplication {
        #if os(macOS)
        // Native XCTest launches with numeric command-line values can start
        // without a window. Exercise the real ten-item limit from seven seeds.
        for index in 0..<3 {
            add("Add Link", app: application)
            let field = application.textFields.matching(NSPredicate(format: "placeholderValue == %@", "https://example.com")).firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.click()
            field.typeText("https://audit.example/capacity-\(index)")
            application.buttons["Save"].click()
            XCTAssertFalse(application.staticTexts["Ten Bookmarks Is Not Enough"].exists)
        }
        #endif
        return application
    }

    private func add(_ title: String, app: XCUIApplication) {
        #if os(macOS)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        if title == "Add Link" {
            app.typeKey("n", modifierFlags: .command)
        } else if title == "New Snippet" {
            app.typeKey("t", modifierFlags: .command)
        } else {
            let menu = app.descendants(matching: .any).matching(identifier: "library.addMenu").firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 5), app.debugDescription)
            menu.click()
            app.menuItems[title].click()
        }
        #else
        app.buttons["Add"].tap()
        app.buttons[title].tap()
        #endif
    }

    func testNewLinkAtLimitPresentsDismissiblePaywall() {
        let app = launch()
        add("Add Link", app: app)
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "https://example.com")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.clickOrTap()
        field.typeText("https://audit.example/ui-limit")
        app.buttons["Save"].clickOrTap()
        XCTAssertTrue(app.staticTexts["Ten Bookmarks Is Not Enough"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)
        app.buttons["Close"].clickOrTap()
        XCTAssertFalse(app.staticTexts["Ten Bookmarks Is Not Enough"].exists)
    }

    func testNewSnippetAtLimitPresentsPaywall() {
        let app = launch()
        add("New Snippet", app: app)
        let editor = app.textViews["Snippet text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.clickOrTap()
        editor.typeText("Disposable audit snippet")
        app.buttons["Save"].clickOrTap()
        XCTAssertTrue(app.staticTexts["Ten Bookmarks Is Not Enough"].waitForExistence(timeout: 5))
    }

    func testExportRemainsAvailableWhenLocked() {
        let app = launch()
        add("Settings", app: app)
        let export = app.buttons["settings.exportJSON"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.clickOrTap()
        #if os(macOS)
        let panel = app.descendants(matching: .sheet).matching(identifier: "save-panel").firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(panel.buttons["OKButton"].isEnabled)
        panel.buttons["CancelButton"].click()
        #else
        // The native Files exporter exposes Cancel to XCTest. Its Save button
        // is visible on screen but absent from the accessibility snapshot.
        let cancel = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Cancel")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), app.debugDescription)
        #endif
        XCTAssertFalse(app.staticTexts["Ten Bookmarks Is Not Enough"].exists)
    }
    func testPurchaseClearsRestoreErrorAndUnlocksRunningApp() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-storekit-audit"), "Run purchase UI tests with the Tucked Audit scheme.")
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Audit", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: fixture)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        application.terminate()
        application.launch()
        let app = launch()
        add("Add Link", app: app)
        let field = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "https://example.com")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.clickOrTap()
        field.typeText("https://audit.example/purchase-flow")
        app.buttons["Save"].clickOrTap()
        XCTAssertTrue(app.staticTexts["Ten Bookmarks Is Not Enough"].waitForExistence(timeout: 5))
        #if !os(macOS)
        for _ in 0..<3 {
            if app.buttons["Restore Purchases"].isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        #endif
        app.buttons["Restore Purchases"].clickOrTap()
        let restoreError = app.staticTexts["No Tucked for Life purchase was found for this Apple Account."]
        XCTAssertTrue(restoreError.waitForExistence(timeout: 5))
        app.buttons["Unlock Tucked for Life"].clickOrTap()
        XCTAssertTrue(restoreError.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ten Bookmarks Is Not Enough"].waitForNonExistence(timeout: 5), "A verified purchase must close the paywall instead of offering another unlock.")
        let paywall = XCTAttachment(screenshot: app.screenshot())
        paywall.name = "Library after verified purchase"
        paywall.lifetime = .keepAlways
        add(paywall)
        add("Settings", app: app)
        let badge = app.descendants(matching: .any).matching(identifier: "settings.proBadge").firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(session.allTransactions().count, 1, "The local StoreKit session must own this transaction.")
        let unlocked = XCTAttachment(screenshot: app.screenshot())
        unlocked.name = "Same-instance unlocked Settings"
        unlocked.lifetime = .keepAlways
        add(unlocked)
    }
}

private extension XCUIElement {
    func clickOrTap() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
