import SwiftData
import SwiftUI

@main
struct BookmarkCollectionsApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    let enricher = MetadataEnricher(
                        context: container.mainContext,
                        provider: LinkPresentationMetadataProvider()
                    )
                    try? await enricher.enrichPending(limit: 20)
                }
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
