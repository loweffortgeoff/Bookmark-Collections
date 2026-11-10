import SwiftData
import XCTest
@testable import BookmarkCollections

@MainActor
final class ModelContainerTests: XCTestCase {
    func testInMemoryContainerCanBeCreated() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        XCTAssertNotNil(container.mainContext.container)
    }

    func testBookmarkRoundTripPreservesOrganization() throws {
        let container = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let collection = BookmarkCollection(name: "Development", sortPosition: 0)
        let bookmark = Bookmark(
            urlString: "https://example.com",
            normalizedURLString: "https://example.com/"
        )
        bookmark.title = "Example"
        bookmark.isFavorite = true
        bookmark.collection = collection
        container.mainContext.insert(collection)
        container.mainContext.insert(bookmark)
        try container.mainContext.save()

        let descriptor = FetchDescriptor<Bookmark>()
        let saved = try XCTUnwrap(container.mainContext.fetch(descriptor).first)
        XCTAssertEqual(saved.title, "Example")
        XCTAssertEqual(saved.collection?.name, "Development")
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.metadataState, .pending)
    }

    func testRuntimeConfigurationUsesAnInMemoryStoreForUnitTests() {
        let configuration = AppRuntimeConfiguration(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
        )

        XCTAssertTrue(configuration.usesInMemoryStore)
        XCTAssertFalse(configuration.usesCloudKit)
    }

    func testRuntimeConfigurationUsesAnInMemoryStoreForUITests() {
        let configuration = AppRuntimeConfiguration(arguments: ["-ui-testing"], environment: [:])

        XCTAssertTrue(configuration.isUITesting)
        XCTAssertTrue(configuration.usesInMemoryStore)
        XCTAssertFalse(configuration.usesCloudKit)
        XCTAssertFalse(configuration.simulatesStoreOpenFailure)
    }

    func testStoreOpenFailureSimulationRequiresAnExplicitUITestLaunch() {
        for environment in [[:], ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]] {
            let configuration = AppRuntimeConfiguration(
                arguments: ["-simulate-store-open-failure"],
                environment: environment
            )

            XCTAssertFalse(configuration.simulatesStoreOpenFailure)
        }
    }

    func testStoreOpenFailureSimulationRequiresADebugBuild() {
        let configuration = AppRuntimeConfiguration(
            arguments: ["-ui-testing", "-simulate-store-open-failure"],
            environment: [:]
        )

        #if DEBUG
        XCTAssertTrue(configuration.simulatesStoreOpenFailure)
        #else
        XCTAssertFalse(configuration.simulatesStoreOpenFailure)
        #endif
        XCTAssertTrue(configuration.usesInMemoryStore)
        XCTAssertFalse(configuration.usesCloudKit)
    }

    func testLibraryOpenReturnsTheCreatedContainer() throws {
        let expected = try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        let runtime = AppRuntimeConfiguration(arguments: [], environment: [:])
        var attempts = 0

        let container = BookmarkCollectionsApp.openLibrary(runtime: runtime) {
            attempts += 1
            return expected
        }

        XCTAssertTrue(container === expected)
        XCTAssertEqual(attempts, 1)
    }

    func testLibraryOpenFailureReturnsNoContainerWithoutRetryOrFallback() {
        let runtime = AppRuntimeConfiguration(arguments: [], environment: [:])
        var attempts = 0

        let container = BookmarkCollectionsApp.openLibrary(runtime: runtime) {
            attempts += 1
            throw CocoaError(.fileReadCorruptFile)
        }

        XCTAssertNil(container)
        XCTAssertEqual(attempts, 1)
    }

    #if DEBUG
    func testSimulatedLibraryOpenFailureDoesNotAttemptToOpenAnyStore() {
        let runtime = AppRuntimeConfiguration(
            arguments: ["-ui-testing", "-simulate-store-open-failure"],
            environment: [:]
        )
        var attempts = 0

        let container = BookmarkCollectionsApp.openLibrary(runtime: runtime) {
            attempts += 1
            return try ModelContainerFactory.make(inMemory: true, cloudKit: false)
        }

        XCTAssertNil(container)
        XCTAssertEqual(attempts, 0)
    }
    #endif

    func testRuntimeConfigurationReadsTheFreeLimitLaunchArgument() {
        let configuration = AppRuntimeConfiguration(
            arguments: ["Tucked", "-free-limit", "1"],
            environment: [:]
        )

        XCTAssertEqual(configuration.freeBookmarkLimitOverride, 1)
    }

    func testRuntimeConfigurationIgnoresAMalformedFreeLimitArgument() {
        for arguments in [["-free-limit"], ["-free-limit", "lots"], ["-free-limit", "-3"]] {
            let configuration = AppRuntimeConfiguration(arguments: arguments, environment: [:])
            XCTAssertNil(
                configuration.freeBookmarkLimitOverride,
                "Expected \(arguments) to be ignored."
            )
        }
    }

    func testRuntimeConfigurationHasNoFreeLimitOverrideByDefault() {
        let configuration = AppRuntimeConfiguration(arguments: [], environment: [:])

        XCTAssertNil(configuration.freeBookmarkLimitOverride)
    }

    func testRuntimeConfigurationUsesTheSharedCloudStoreNormally() {
        let configuration = AppRuntimeConfiguration(arguments: [], environment: [:])

        XCTAssertFalse(configuration.usesInMemoryStore)
        XCTAssertTrue(configuration.usesCloudKit)
    }
}
