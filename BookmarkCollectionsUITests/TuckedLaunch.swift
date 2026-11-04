import XCTest

extension XCUIApplication {
    /// Arguments every UI test launch adds after its own.
    ///
    /// Mac: skip AppKit window restoration. Saved window state belongs to the
    /// bundle ID, so every Tucked copy on this Mac shares it (Debug, the
    /// `~/Applications` Release copy, TestFlight). A copy that closed its
    /// window and stays in the menu bar writes state with no window. A launch
    /// under XCTest that restores that state shows a menu bar and no window,
    /// and the whole suite fails. Ignoring the state also keeps tests from
    /// writing it.
    static var tuckedLaunchDefaults: [String] {
        #if os(macOS)
        ["-ApplePersistenceIgnoreState", "YES"]
        #else
        []
        #endif
    }

    /// A Tucked app set up for UI tests with `arguments` plus the shared defaults.
    static func tucked(_ arguments: [String] = ["-ui-testing"]) -> XCUIApplication {
        let app = XCUIApplication()
        #if os(macOS)
        // Under XCTest a bare value such as "YES" in the arguments stops the
        // initial window from opening (seen 2026-11-04; the AppKit mechanism
        // is not confirmed). After "--" it does not, and Foundation still
        // reads the arguments as defaults.
        app.launchArguments = ["--"] + arguments + tuckedLaunchDefaults
        #else
        app.launchArguments = arguments + tuckedLaunchDefaults
        #endif
        return app
    }
}
