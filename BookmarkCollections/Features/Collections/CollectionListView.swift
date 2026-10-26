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
            Section {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems", showsCount: true)
                destinationRow(.images, title: "Images", identifier: "destination.images", showsCount: true)
                destinationRow(.links, title: "Links", identifier: "destination.links", showsCount: true)
                destinationRow(.snippets, title: "Snippets", identifier: "destination.snippets", showsCount: true)
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", showsCount: true)
                destinationRow(.forgotten, title: "Forgotten", identifier: "destination.forgotten", showsCount: true)
            } header: {
                Text("Library")
                    .padding(.top, 2)
            }

            Section {
                if collections.isEmpty {
                    Button("Create Collection", systemImage: "folder.badge.plus", action: onCreate)
                } else {
                    ForEach(Array(collections.enumerated()), id: \.element.id) { index, collection in
                        let destination = LibraryDestination.collection(collection.id)
                        destinationRow(
                            destination,
                            title: collection.name,
                            identifier: index == 0
                                ? "destination.collections"
                                : "destination.collection.\(collection.id)",
                            showsCount: true
                        )
                        .contextMenu {
                            Button("Rename") { onEdit(collection) }
                            Button("Delete", role: .destructive) { onDelete(collection) }
                        }
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
                .padding(.top, 2)
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
        Label {
            Text(title)
        } icon: {
            if selection == destination {
                Image(systemName: destination.systemImage)
            } else {
                Image(systemName: destination.systemImage)
                    .foregroundStyle(Color.accentColor)
            }
        }
            .modifier(OptionalCountBadge(count: showsCount ? count(for: destination) : nil))
            .tag(destination)
            // The identifier must ride on the whole row: SwiftUI List labels
            // otherwise let the SF Symbol image claim it, and the test taps a
            // 20pt image inside a non-hittable cell instead of the row.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

private struct OptionalCountBadge: ViewModifier {
    let count: Int?

    func body(content: Content) -> some View {
        if let count {
            content.badge(count)
        } else {
            content
        }
    }
}
