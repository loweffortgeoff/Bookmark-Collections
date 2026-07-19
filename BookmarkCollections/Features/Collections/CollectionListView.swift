import SwiftData
import SwiftUI

struct CollectionListView: View {
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]

    @Binding var selection: LibraryDestination?
    let onCreate: () -> Void
    let onEdit: (BookmarkCollection) -> Void
    let onDelete: (BookmarkCollection) -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems", showsCount: true)
                destinationRow(.images, title: "Images", identifier: "destination.images", showsCount: true)
                destinationRow(.links, title: "Links", identifier: "destination.links", showsCount: true)
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", showsCount: true)
            }

            Section {
                if collections.isEmpty {
                    Button("Create Collection", systemImage: "folder.badge.plus", action: onCreate)
                } else {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        let destination = LibraryDestination.collection(collection.id)
                        NavigationLink(value: destination) {
                            HStack {
                                Label(collection.name, systemImage: "folder")
                                Spacer()
                                Text("\(count(for: destination))")
                                    .foregroundStyle(.tint)
                                    .accessibilityLabel("\(count(for: destination)) items")
                            }
                            .contextMenu {
                                Button("Rename") { onEdit(collection) }
                                Button("Delete", role: .destructive) { onDelete(collection) }
                            }
                        }
                        .tag(destination)
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
                    identifier: "destination.recentlyDeleted",
                    showsCount: false
                )
            }
        }
        .listStyle(.sidebar)
    }

    private func count(for destination: LibraryDestination) -> Int {
        destination.count(in: bookmarks)
    }

    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String,
        showsCount: Bool
    ) -> some View {
        NavigationLink(value: destination) {
            HStack {
                Label(title, systemImage: destination.systemImage)
                if showsCount {
                    Spacer()
                    Text("\(count(for: destination))")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("\(count(for: destination)) items")
                }
            }
        }
        .tag(destination)
        .accessibilityIdentifier(identifier)
    }
}
