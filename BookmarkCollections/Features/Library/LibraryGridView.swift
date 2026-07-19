import SwiftData
import SwiftUI

struct LibraryGridView: View {
    @Environment(\.modelContext) private var modelContext

    let bookmarks: [Bookmark]
    let collections: [BookmarkCollection]
    let destination: LibraryDestination
    let searchText: String
    let sort: BookmarkSort
    let ascending: Bool
    let onAdd: () -> Void
    let onEdit: (Bookmark) -> Void
    let onPermanentDelete: (Bookmark) -> Void
    let onError: (String) -> Void
    let onCommandSelection: (Bookmark) -> Void

    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []

    private var visibleBookmarks: [Bookmark] {
        bookmarks
            .filter { destination.matches($0, searchText: searchText) }
            .sorted(using: sort.descriptors(ascending: ascending))
    }

    var body: some View {
        VStack(spacing: 0) {
            if destination != .recentlyDeleted && !visibleBookmarks.isEmpty {
                HStack {
                    Spacer()
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting { selection.removeAll() }
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("selection.toggle")
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }

            Group {
                if visibleBookmarks.isEmpty {
                    emptyState
                } else {
                    GeometryReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(visibleBookmarks) { bookmark in
                                    ZStack(alignment: .topTrailing) {
                                        BookmarkCard(
                                            bookmark: bookmark,
                                            onOpen: isSelecting ? { toggleSelection(bookmark) } : nil,
                                            onCommandSelection: { onCommandSelection(bookmark) }
                                        )
                                        if isSelecting {
                                            Image(systemName: selection.contains(bookmark.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.title2)
                                                .foregroundStyle(selection.contains(bookmark.id) ? Color.accentColor : Color.secondary)
                                                .padding(10)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .contextMenu {
                                        BookmarkActions(
                                            bookmark: bookmark,
                                            isRecentlyDeleted: destination == .recentlyDeleted,
                                            onEdit: { onEdit(bookmark) },
                                            onPermanentDelete: { onPermanentDelete(bookmark) },
                                            onError: onError
                                        )
                                    }
                                }
                            }
                            .padding()
                        }
                        // iPadOS windowed resize doesn't reliably re-propose width to
                        // already-materialized LazyVGrid cells, leaving stale/clipped
                        // geometry ("window shade" effect). Forcing a fresh grid
                        // identity when the available width crosses a coarse bucket
                        // discards the stale cells instead of relaying them out in place.
                        .id(Int(proxy.size.width / 20))
                        .dropDestination(for: URL.self) { urls, _ in
                            do {
                                let repository = BookmarkRepository(context: modelContext)
                                for url in urls where ["http", "https"].contains(url.scheme?.lowercased()) {
                                    _ = try repository.save(url: url.absoluteString)
                                }
                                return true
                            } catch {
                                onError(error.localizedDescription)
                                return false
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionBar
            }
        }
    }

    private var selectedBookmarks: [Bookmark] {
        visibleBookmarks.filter { selection.contains($0.id) }
    }

    private var selectionBar: some View {
        HStack(spacing: 14) {
            Button("Favorite", systemImage: "star") {
                updateSelection { $0.isFavorite = true }
            }
            Button("Unfavorite", systemImage: "star.slash") {
                updateSelection { $0.isFavorite = false }
            }
            Menu {
                Button("Unfiled") { moveSelection(to: nil) }
                ForEach(collections) { collection in
                    Button(collection.name) { moveSelection(to: collection) }
                }
            } label: {
                Label("Move", systemImage: "folder")
            }
            ShareLink(items: selectedBookmarks.compactMap { URL(string: $0.urlString) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                let now = Date()
                updateSelection {
                    $0.deletedAt = now
                    $0.modifiedAt = now
                }
            }
            .accessibilityIdentifier("selection.delete")
        }
        .disabled(selection.isEmpty)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func toggleSelection(_ bookmark: Bookmark) {
        if !selection.insert(bookmark.id).inserted {
            selection.remove(bookmark.id)
        }
    }

    private func moveSelection(to collection: BookmarkCollection?) {
        updateSelection { $0.collection = collection }
    }

    private func updateSelection(_ update: (Bookmark) -> Void) {
        let now = Date()
        for bookmark in selectedBookmarks {
            update(bookmark)
            bookmark.modifiedAt = now
        }
        do {
            try modelContext.save()
            selection.removeAll()
            isSelecting = false
        } catch {
            onError(error.localizedDescription)
        }
    }

    private var columns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 18)]
        #else
        [GridItem(.adaptive(minimum: 160, maximum: 210), spacing: 14)]
        #endif
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            switch destination {
            case .recentlyDeleted:
                ContentUnavailableView(
                    "Recently Deleted Is Empty",
                    systemImage: "trash",
                    description: Text("Deleted bookmarks remain recoverable here for 30 days.")
                )
            case .favorites:
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Favorite a bookmark to find it here.")
                )
            case .collection:
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "folder",
                    description: Text("Move bookmarks into this collection from their Edit menu.")
                )
            case .allItems:
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Share a link from another app or add one here.")
                )
                Button("Add Link", action: onAdd)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
