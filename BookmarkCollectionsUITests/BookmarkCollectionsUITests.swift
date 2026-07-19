import XCTest

@MainActor
final class BookmarkCollectionsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    func testPrimaryLibraryDestinationsAreReachable() {
        showSidebarIfNeeded()
        XCTAssertTrue(destinationElement("destination.allItems").waitForExistence(timeout: 5))

        activate(destinationElement("destination.favorites"))
        XCTAssertTrue(identified("library.favorites").waitForExistence(timeout: 2))

        showSidebarIfNeeded()
        activate(destinationElement("destination.collections"))
        XCTAssertTrue(
            identified("library.collection").waitForExistence(timeout: 2)
                || app.navigationBars["Reading"].exists
        )

        showSidebarIfNeeded()
        activate(destinationElement("destination.recentlyDeleted"))
        XCTAssertTrue(identified("library.recentlyDeleted").waitForExistence(timeout: 2))
    }

    func testSeededCardOpensEditorFromContextMenu() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.allItems"))
        let card = identified("bookmark.seeded-active")
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        activateContextMenu(on: card)
        activate(contextMenuItem("Edit"))

        XCTAssertTrue(identified("bookmarkEditor").waitForExistence(timeout: 2))
    }

    func testSeededCardOpensInfoPanelFromContextMenu() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.allItems"))
        let card = identified("bookmark.seeded-active")
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        activateContextMenu(on: card)
        activate(contextMenuItem("Get Info"))

        XCTAssertTrue(identified("bookmarkInfo").waitForExistence(timeout: 2))
    }

    func testPermanentDeletionRequiresConfirmation() {
        showSidebarIfNeeded()
        let recentlyDeleted = destinationElement("destination.recentlyDeleted")
        XCTAssertTrue(recentlyDeleted.waitForExistence(timeout: 5))
        activate(recentlyDeleted)
        let card = identified("bookmark.seeded-deleted")
        XCTAssertTrue(card.waitForExistence(timeout: 2))

        activateContextMenu(on: card)
        activate(contextMenuItem("Delete Permanently"))

        XCTAssertTrue(
            identified("Delete Permanently?").waitForExistence(timeout: 2)
        )
    }

    func testEmptyRecentlyDeletedRequiresConfirmation() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.recentlyDeleted"))
        let emptyButton = identified("recentlyDeleted.empty")
        XCTAssertTrue(emptyButton.waitForExistence(timeout: 2))

        activate(emptyButton)

        XCTAssertTrue(
            identified("Empty Recently Deleted?").waitForExistence(timeout: 2)
        )
    }

    func testSelectionModeOffersBulkActions() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.allItems"))
        let selectButton = identified("selection.toggle")
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        activate(selectButton)
        activate(identified("bookmark.seeded-active"))

        XCTAssertTrue(identified("selection.delete").waitForExistence(timeout: 2))
    }

    func testBookmarkCardExposesOrganizationAndFavoriteState() {
        showSidebarIfNeeded()
        activate(destinationElement("destination.allItems"))
        let card = identified("bookmark.seeded-active")
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        XCTAssertEqual(card.label, "Seeded Active")
        let value = card.value as? String ?? ""
        XCTAssertTrue(value.contains("example.com"))
        XCTAssertTrue(value.contains("Reading"))
        XCTAssertTrue(value.contains("Favorite"))
    }

    func testSettingsExposesImportExportAndICloudStatus() {
        #if os(macOS)
        let addMenu = identified("library.addMenu")
        #else
        let addMenu = app.buttons["Add"]
        #endif
        XCTAssertTrue(addMenu.waitForExistence(timeout: 5))
        activate(addMenu)
        activate(contextMenuItem("Settings"))

        XCTAssertTrue(identified("settings.importLinks").waitForExistence(timeout: 2))
        XCTAssertTrue(identified("settings.exportHTML").exists)
        XCTAssertTrue(identified("settings.exportJSON").exists)
        XCTAssertTrue(identified("settings.syncStatus").exists)
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "library.allItems")
                .firstMatch
                .waitForExistence(timeout: 5)
        )
    }

    private func activateContextMenu(on element: XCUIElement) {
        #if os(macOS)
        element.rightClick()
        #else
        element.press(forDuration: 1)
        #endif
    }

    private func identified(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func destinationElement(_ identifier: String) -> XCUIElement {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        return button.exists ? button : app.staticTexts.matching(identifier: identifier).firstMatch
    }

    private func contextMenuItem(_ title: String) -> XCUIElement {
        #if os(macOS)
        app.menuItems[title]
        #else
        app.buttons[title]
        #endif
    }

    private func activate(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    private func showSidebarIfNeeded() {
        #if !os(macOS)
        let backButton = app.navigationBars.buttons["Bookmarks"]
        if backButton.exists {
            activate(backButton)
        }
        #endif
    }
}
