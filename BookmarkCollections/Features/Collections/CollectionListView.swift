import SwiftData
import SwiftUI

struct CollectionListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    ForEach(Array(collections.enumerated()), id: \.element.persistentModelID) { index, collection in
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
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Collections")
                            .fixedSize()
                        Spacer()
                        newCollectionButton
                    }
                    VStack(alignment: .leading) {
                        Text("Collections")
                            .fixedSize(horizontal: true, vertical: false)
                        newCollectionButton
                    }
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

    private var newCollectionButton: some View {
        Button(action: onCreate) {
            Image(systemName: "plus")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New Collection")
    }

    private func destinationRow(
        _ destination: LibraryDestination,
        title: String,
        identifier: String,
        count: Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Image(systemName: destination.systemImage)
                        .foregroundStyle(selection == destination ? Color.primary : Color.accentColor)
                    Spacer()
                    if let count {
                        Text(count, format: .number)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
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
            }
        }
        .modifier(OptionalCountBadge(count: dynamicTypeSize.isAccessibilitySize ? nil : count))
        .listRowInsets(dynamicTypeSize.isAccessibilitySize ? EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0) : nil)
        .tag(destination)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(count?.formatted(.number) ?? "")
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
