import Foundation
import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ImageImportTests: XCTestCase {
    func testImportingImageFilesSavesDownsampledImageBookmarks() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("Screenshot One.png")
        try Self.pngData(width: 40, height: 30).write(to: first)
        let second = directory.appendingPathComponent("Screenshot Two.png")
        try Self.pngData(width: 20, height: 20).write(to: second)

        let service = ImageImportService(context: container.mainContext)
        let summary = try service.importImages(at: [first, second])

        XCTAssertEqual(summary.newCount, 2)
        XCTAssertTrue(summary.failedLines.isEmpty)

        let bookmarks = try container.mainContext.fetch(FetchDescriptor<Bookmark>())
        XCTAssertEqual(bookmarks.count, 2)
        XCTAssertTrue(bookmarks.allSatisfy { $0.kind == .image })
        XCTAssertTrue(bookmarks.allSatisfy { $0.previewImageData != nil })
        XCTAssertTrue(bookmarks.allSatisfy { $0.collection == nil })
        XCTAssertTrue(bookmarks.allSatisfy { !$0.isFavorite })
        XCTAssertEqual(
            Set(bookmarks.map(\.title)),
            ["Screenshot One", "Screenshot Two"]
        )
    }

    func testOneUnreadableFileDoesNotCostTheRestOfTheBatch() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let good = directory.appendingPathComponent("Good.png")
        try Self.pngData(width: 40, height: 30).write(to: good)
        let bad = directory.appendingPathComponent("Bad.png")
        try Data("not an image".utf8).write(to: bad)

        let service = ImageImportService(context: container.mainContext)
        let summary = try service.importImages(at: [good, bad])

        XCTAssertEqual(summary.newCount, 1)
        XCTAssertEqual(summary.failedLines, ["Bad.png"])
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Bookmark>()).count, 1)
    }

    func testLockedImageBatchStopsAtTenWithoutCreatingAnEleventh() throws {
        let oldAccess = PurchaseAccess.isUnlocked
        let oldAvailability = PurchaseAccess.isProductAvailable
        PurchaseAccess.setUnlocked(false)
        PurchaseAccess.setProductAvailable(true)
        defer {
            PurchaseAccess.setUnlocked(oldAccess)
            PurchaseAccess.setProductAvailable(oldAvailability)
        }
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let repository = BookmarkRepository(context: container.mainContext, isUnlocked: true)
        for index in 0..<9 { _ = try repository.save(url: "https://audit.example/image-batch/\(index)") }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("First.png")
        let second = directory.appendingPathComponent("Second.png")
        try Self.pngData(width: 20, height: 20).write(to: first)
        try Self.pngData(width: 20, height: 20).write(to: second)
        XCTAssertThrowsError(try ImageImportService(context: container.mainContext).importImages(at: [first, second])) {
            XCTAssertEqual($0 as? BookmarkRepository.LimitError, .limitReached)
        }
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<Bookmark>()), 10)
    }

    /// A minimal opaque PNG, built through the platform image encoder so the
    /// bytes are whatever ImageDownsampler actually accepts.
    private static func pngData(width: Int, height: Int) throws -> Data {
        let context = try XCTUnwrap(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.setFillColor(red: 0.4, green: 0.6, blue: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())

        let output = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
