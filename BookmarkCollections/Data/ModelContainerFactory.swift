import SwiftData

enum ModelContainerFactory {
    static let appGroupIdentifier = "group.com.loweffortapps.BookmarkCollections"

    static func make(inMemory: Bool, cloudKit: Bool) throws -> ModelContainer {
        let schema = Schema([Bookmark.self, BookmarkCollection.self])
        let configuration = ModelConfiguration(
            "BookmarkCollections",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: inMemory ? .automatic : .identifier(appGroupIdentifier),
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

