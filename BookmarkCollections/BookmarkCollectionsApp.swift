import SwiftData
import SwiftUI

@main
struct BookmarkCollectionsApp: App {
    private let container = try! ModelContainerFactory.make(inMemory: false, cloudKit: true)

    var body: some Scene {
        WindowGroup {
            Text("Bookmarks")
        }
        .modelContainer(container)
    }
}

enum ModelContainerFactory {
    static func make(inMemory: Bool, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([ScaffoldRecord.self])
        let configuration = ModelConfiguration(
            "BookmarkCollectionsScaffold",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

@Model
final class ScaffoldRecord {
    var createdAt = Date()

    init() {}
}
