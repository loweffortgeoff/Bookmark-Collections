import SwiftData
import SwiftUI

struct CollectionListView: View {
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]

    @Binding var selection: LibraryDestination?
    let onCreate: () -> Void
    let onEdit: (BookmarkCollection) -> Void
    let onDelete: (BookmarkCollection) -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems")
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites")
            }

            Section {
                if collections.isEmpty {
                    Button("Create Collection", systemImage: "folder.badge.plus", action: onCreate)
                } else {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        NavigationLink(value: LibraryDestination.collection(collection.id)) {
                            Label(collection.name, systemImage: "folder")
                                .contextMenu {
                                    Button("Rename") { onEdit(collection) }
                                    Button("Delete", role: .destructive) { onDelete(collection) }
                                }
                        }
                            .tag(LibraryDestination.collection(collection.id))
                            .accessibilityIdentifier(index == 0 ? "destination.collections" : "destination.collection.\(collection.id)")
                    }
                }
            } header: {
                HStack {
                    Text("Collections")
                    Spacer()
                    Button(action: onCreate) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New Collection")
                }
            }

            Section {
                destinationRow(
                    .recentlyDeleted,
                    title: "Recently Deleted",
                    identifier: "destination.recentlyDeleted"
                )
            }
        }
        .listStyle(.sidebar)
    }

    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String
    ) -> some View {
        NavigationLink(value: destination) {
            Label(title, systemImage: destination.systemImage)
        }
        .tag(destination)
        .accessibilityIdentifier(identifier)
    }
}
