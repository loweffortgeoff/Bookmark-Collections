import SwiftData
import SwiftUI

struct CollectionListView: View {
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]

    @AppStorage(AppAccent.storageKey) private var accentKey = AppAccent.defaultAccent.rawValue

    @Binding var selection: LibraryDestination?
    let onCreate: () -> Void
    let onEdit: (BookmarkCollection) -> Void
    let onDelete: (BookmarkCollection) -> Void

    var body: some View {
        // Rows are Buttons that write the selection binding rather than tagged
        // List rows: the untinted native highlight never draws, while the
        // List(selection:) wrapper keeps NavigationSplitView pushing the detail
        // column on compact widths when the binding changes.
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
                        SidebarRow(
                            title: collection.name,
                            systemImage: "folder",
                            count: count(for: destination),
                            accent: accent,
                            isSelected: selection == destination
                        ) {
                            selection = destination
                        }
                        .contextMenu {
                            Button("Rename") { onEdit(collection) }
                            Button("Delete", role: .destructive) { onDelete(collection) }
                        }
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

    private var accent: Color {
        AppAccent(storedKey: accentKey).color
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
        SidebarRow(
            title: title,
            systemImage: destination.systemImage,
            count: showsCount ? count(for: destination) : nil,
            accent: accent,
            isSelected: selection == destination
        ) {
            selection = destination
        }
        .accessibilityIdentifier(identifier)
    }
}

/// Sidebar row with the accent pill selection treatment: a soft accent-tinted
/// rounded background plus a full-accent left bar, while the title stays on
/// `.primary` so selected text never depends on the accent for legibility.
private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let count: Int?
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label {
                    Text(title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(accent)
                }
                if let count {
                    Spacer()
                    Text("\(count)")
                        .fontWeight(.semibold)
                        .foregroundStyle(accent)
                        .accessibilityLabel("\(count) items")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(background)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.16))
                Capsule()
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 7)
            }
        }
    }
}
