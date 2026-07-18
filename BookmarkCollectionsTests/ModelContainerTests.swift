import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ModelContainerTests: XCTestCase {
    func testInMemoryContainerCanBeCreated() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        XCTAssertNotNil(container.mainContext.container)
    }
}
