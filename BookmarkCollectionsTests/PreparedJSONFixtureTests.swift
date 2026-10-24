import SwiftData
import XCTest
@testable import BookmarkCollections

#if os(macOS)
@MainActor
final class PreparedJSONFixtureTests: XCTestCase {
    func testFivePreparedFilesThroughActualImporter() throws {
        let oldAccess = PurchaseAccess.isUnlocked
        defer { PurchaseAccess.setUnlocked(oldAccess) }
        PurchaseAccess.setUnlocked(false)
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let context = container.mainContext
        let importer = LibraryImportService(context: context)
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/verification/fixtures/2026-10-23-testflight")
        func read(_ name: String) throws -> Data { try Data(contentsOf: directory.appendingPathComponent(name)) }
        _ = try importer.importJSON(read("01-seed-10-free.json"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
        _ = try importer.importJSON(read("02-update-same-10.json"))
        _ = try importer.importJSON(read("03-same-url-new-id.json"))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Bookmark>()), 10)
        let before = try LibraryExportService(context: context).exportJSON()
        XCTAssertThrowsError(try importer.importJSON(read("04-reject-11-new.json")))
        XCTAssertThrowsError(try importer.importJSON(read("05-expand-to-12-after-unlock.json")))
        XCTAssertEqual(try LibraryExportService(context: context).exportJSON(), before)
        XCTAssertFalse(context.hasChanges)
        PurchaseAccess.setUnlocked(true)
        _ = try importer.importJSON(read("05-expand-to-12-after-unlock.json"))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Bookmark>()), 12)
    }
}
#endif
