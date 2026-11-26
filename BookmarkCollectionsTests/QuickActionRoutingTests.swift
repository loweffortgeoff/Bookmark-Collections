import XCTest
@testable import BookmarkCollections

@MainActor
final class QuickActionRoutingTests: XCTestCase {
    func testAllFourShortcutTypesMapToExpectedRouterRequests() {
        let expected: [String: MenuBarRequest] = [
            "com.loweffortapps.BookmarkCollections.quickaction.addLink": .addLink(prefilledURL: nil),
            "com.loweffortapps.BookmarkCollections.quickaction.saveFromClipboard": .saveFromClipboard,
            "com.loweffortapps.BookmarkCollections.quickaction.newSnippet": .newSnippet,
            "com.loweffortapps.BookmarkCollections.quickaction.search": .search
        ]
        XCTAssertEqual(HomeScreenQuickAction.allCases.count, 4)
        for (type, request) in expected {
            XCTAssertEqual(HomeScreenQuickAction(rawValue: type)?.routerRequest, request, type)
        }
    }

    func testUnknownShortcutTypeReturnsNil() {
        XCTAssertNil(HomeScreenQuickAction(rawValue: "unknown"))
    }

    func testColdLaunchQueuedActionConsumedOnceOnMount() {
        let router = MenuBarRouter()
        router.request(HomeScreenQuickAction.newSnippet.routerRequest)

        XCTAssertEqual(router.pending, .newSnippet)
        XCTAssertEqual(router.consume(blocked: false), .newSnippet)
        XCTAssertNil(router.consume(blocked: false))
    }

    func testInfoPlistDeclaresAllFourQuickActionTypes() throws {
        let items = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIApplicationShortcutItems") as? [[String: Any]]
        )
        let types = items.compactMap { $0["UIApplicationShortcutItemType"] as? String }
        XCTAssertEqual(Set(types), Set(HomeScreenQuickAction.allCases.map(\.rawValue)))
        for item in items {
            XCTAssertFalse((item["UIApplicationShortcutItemTitle"] as? String ?? "").isEmpty)
            XCTAssertFalse((item["UIApplicationShortcutItemIconSymbolName"] as? String ?? "").isEmpty)
        }
    }
}
