import SwiftData
import SwiftUI

@main
struct BookmarkCollectionsApp: App {
    private let container: ModelContainer

    init() {
        let runtime = AppRuntimeConfiguration()
        container = try! ModelContainerFactory.make(
            inMemory: runtime.usesInMemoryStore,
            cloudKit: runtime.usesCloudKit
        )
    }

    var body: some Scene {
        WindowGroup {
            Text("Bookmarks")
        }
        .modelContainer(container)
    }
}

struct AppRuntimeConfiguration {
    let usesInMemoryStore: Bool
    let usesCloudKit: Bool

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        usesInMemoryStore = environment["XCTestConfigurationFilePath"] != nil
        usesCloudKit = !usesInMemoryStore
    }
}
