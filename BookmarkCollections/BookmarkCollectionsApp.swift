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
        if runtime.isUITesting {
            Self.seedUITestLibrary(in: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            LibraryRootView()
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    try? BookmarkRepository(context: container.mainContext).reconcileDuplicates()
                    let enricher = MetadataEnricher(
                        context: container.mainContext,
                        provider: LinkPresentationMetadataProvider()
                    )
                    try? await enricher.enrichPending(limit: 20)
                }
        }
        .modelContainer(container)
        .commands {
            #if os(macOS)
            BookmarkCommands()
            #endif
        }
    }

    @MainActor
    private static func seedUITestLibrary(in context: ModelContext) {
        let collection = BookmarkCollection(name: "Reading", sortPosition: 0)
        let active = Bookmark(
            urlString: "https://example.com/seeded-active",
            normalizedURLString: "https://example.com/seeded-active"
        )
        active.title = "Seeded Active"
        active.domain = "example.com"
        active.collection = collection
        active.isFavorite = true
        active.metadataState = .ready
        let deleted = Bookmark(
            urlString: "https://example.com/seeded-deleted",
            normalizedURLString: "https://example.com/seeded-deleted"
        )
        deleted.title = "Seeded Deleted"
        deleted.domain = "example.com"
        deleted.deletedAt = Date()
        deleted.metadataState = .ready
        context.insert(collection)
        context.insert(active)
        context.insert(deleted)
        try? context.save()
    }
}

struct AppRuntimeConfiguration {
    let usesInMemoryStore: Bool
    let usesCloudKit: Bool
    let isUITesting: Bool

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        isUITesting = arguments.contains("-ui-testing")
        usesInMemoryStore = environment["XCTestConfigurationFilePath"] != nil || isUITesting
        usesCloudKit = !usesInMemoryStore
    }
}
