import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

/// Seeds the simulator's on-disk library for App Store screenshots.
///
/// Skips unless `TUCKED_SEED_DIR` is set. Pass it through xcodebuild as
/// `TEST_RUNNER_TUCKED_SEED_DIR=<folder>`. The folder holds `library.json`
/// (a Tucked JSON backup), `images.tsv` (`file<TAB>title<TAB>collection<TAB>favorite`),
/// and `images/<file>.png`. The seed replaces the whole library on that simulator.
/// Run it only on a simulator with no iCloud account, so nothing syncs.
@MainActor
final class ScreenshotSeedTests: XCTestCase {
    func testSeedScreenshotLibrary() throws {
        guard let path = ProcessInfo.processInfo.environment["TUCKED_SEED_DIR"], !path.isEmpty else {
            throw XCTSkip("TUCKED_SEED_DIR not set")
        }
        let folder = URL(fileURLWithPath: path)
        let container = try ModelContainerFactory.make(inMemory: false, cloudKit: false)
        let context = container.mainContext

        try context.delete(model: Bookmark.self)
        try context.delete(model: BookmarkCollection.self)
        try context.save()

        // Screenshots show the unlocked app, and the import honors the free limit.
        PurchaseAccess.setUnlocked(true)
        let json = try Data(contentsOf: folder.appendingPathComponent("library.json"))
        let summary = try LibraryImportService(context: context).importJSON(json)
        XCTAssertTrue(summary.failedLines.isEmpty, "\(summary.failedLines)")

        let collections = try context.fetch(FetchDescriptor<BookmarkCollection>())
        let byName = Dictionary(collections.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        // Spread images across the same months as the backup, newest first in file order.
        let manifest = try String(contentsOf: folder.appendingPathComponent("images.tsv"), encoding: .utf8)
        let rows = manifest.split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
        let anchor = Date().addingTimeInterval(-86_400 - 5 * 3_600)
        var inserted = 0
        for (index, row) in rows.enumerated() where row.count >= 4 {
            let file = folder.appendingPathComponent("images/\(row[0]).png")
            let data = try Data(contentsOf: file)
            let created = anchor.addingTimeInterval(-Double(index) * 1.85 * 86_400 - Double(index % 5) * 3_700)
            let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: created)
            bookmark.kind = .image
            bookmark.title = String(row[1])
            bookmark.previewImageData = data
            bookmark.collection = row[2].isEmpty ? nil : byName[String(row[2])]
            bookmark.isFavorite = row[3] == "1"
            bookmark.metadataState = .ready
            context.insert(bookmark)
            inserted += 1
        }
        try context.save()

        let all = try context.fetch(FetchDescriptor<Bookmark>())
        print("SEED: \(all.count) bookmarks, \(inserted) images, \(collections.count) collections")
        XCTAssertEqual(inserted, rows.count)
    }
}
