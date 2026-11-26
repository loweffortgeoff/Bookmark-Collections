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

    func testWeAlsoMakeListsFiveLiveAppsAndExcludesTucked() {
        let apps = LowEffortApps.otherApps
        XCTAssertEqual(apps.count, 5)
        XCTAssertEqual(apps.map(\.name), ["Task(ed)", "EveryPaw", "AisleWise", "Weather in Words", "Offshoots"])
        XCTAssertFalse(apps.contains { $0.name.contains("Tucked") })
        XCTAssertFalse(apps.contains { $0.appStoreID == "6792490401" })
    }

    func testRateAndReviewOpensTuckedWriteReviewPage() {
        XCTAssertEqual(
            LowEffortApps.tuckedWriteReviewURL.absoluteString,
            "https://apps.apple.com/app/id6792490401?action=write-review"
        )
    }

    func testWeAlsoMakeUsesVerifiedLiveAppStoreIDsAndValidURLs() {
        let apps = LowEffortApps.otherApps
        let weather = apps.first { $0.name == "Weather in Words" }
        XCTAssertEqual(weather?.appStoreID, "6806063498")
        XCTAssertFalse(apps.contains { $0.appStoreID == "6760272161" })
        XCTAssertEqual(
            apps.map { $0.appStoreURL?.absoluteString },
            [
                "https://apps.apple.com/us/app/task-ed/id6755186421",
                "https://apps.apple.com/us/app/everypaw/id6754781167",
                "https://apps.apple.com/us/app/aislewise/id6755057084",
                "https://apps.apple.com/us/app/weather-in-words/id6806063498",
                "https://apps.apple.com/us/app/offshoots/id6757363128"
            ]
        )
    }
}
