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
        let counts = LibraryDestination.counts(in: bookmarks)
        List(selection: $selection) {
            Section {
                destinationRow(.allItems, title: "All Items", identifier: "destination.allItems", count: counts[.allItems, default: 0])
                destinationRow(.images, title: "Images", identifier: "destination.images", count: counts[.images, default: 0])
                destinationRow(.links, title: "Links", identifier: "destination.links", count: counts[.links, default: 0])
                destinationRow(.snippets, title: "Snippets", identifier: "destination.snippets", count: counts[.snippets, default: 0])
                destinationRow(.favorites, title: "Favorites", identifier: "destination.favorites", count: counts[.favorites, default: 0])
                destinationRow(.forgotten, title: "Forgotten", identifier: "destination.forgotten", count: counts[.forgotten, default: 0])
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
                            count: counts[destination, default: 0]
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
                    count: nil
                )
            }
        }
        .listStyle(.sidebar)
    }

    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String,
        count: Int?
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
            .modifier(OptionalCountBadge(count: count))
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
