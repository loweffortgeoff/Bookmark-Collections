import SwiftData
import SwiftUI

struct LibraryGridView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let bookmarks: [Bookmark]
    let collections: [BookmarkCollection]
    let destination: LibraryDestination
    let searchText: String
    let sort: BookmarkSort
    let ascending: Bool
    let onAdd: () -> Void
    let onEdit: (Bookmark) -> Void
    let onInfo: (Bookmark) -> Void
    let onOpen: (Bookmark) -> Void
    let onPermanentDelete: (Bookmark) -> Void
    let onError: (String) -> Void
    let onLimitReached: () -> Void
    let onCommandSelection: (Bookmark) -> Void

    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []

    private var visibleBookmarks: [Bookmark] {
        let query = LibraryDestination.searchQuery(searchText)
        return bookmarks
            .filter { destination.matches($0, query: query) }
            .sorted(using: sort.descriptors(ascending: ascending))
    }

    var body: some View {
        // Filtering and sorting walks the whole library, so do it once per
        // body pass rather than once for each place that reads the result.
        let visible = visibleBookmarks
        VStack(spacing: 0) {
            Group {
                if visible.isEmpty {
                    emptyState
                } else {
                    GeometryReader { proxy in
                        let layout = GridLayout(width: proxy.size.width, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
                        ScrollView {
                            LazyVGrid(columns: layout.columns, spacing: 18) {
                                ForEach(visible) { bookmark in
                                    ZStack(alignment: .topTrailing) {
                                        BookmarkCard(
                                            bookmark: bookmark,
                                            onOpen: cardOpenAction(for: bookmark),
                                            onCommandSelection: { onCommandSelection(bookmark) }
                                        )
                                        .frame(width: layout.cellWidth)
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
                                            onInfo: { onInfo(bookmark) },
                                            onPermanentDelete: { onPermanentDelete(bookmark) },
                                            onError: onError
                                        )
                                    }
                                }
                            }
                            .padding(GridLayout.padding)
                        }
                        .dropDestination(for: URL.self) { urls, _ in
                            do {
                                let repository = BookmarkRepository(context: modelContext)
                                for url in urls where ["http", "https"].contains(url.scheme?.lowercased()) {
                                    _ = try repository.save(url: url.absoluteString)
                                }
                                return true
                            } catch {
                                if error as? BookmarkRepository.LimitError == .limitReached {
                                    onLimitReached()
                                } else {
                                    onError(error.localizedDescription)
                                }
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
        .toolbar {
            if destination != .recentlyDeleted && !visible.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting { selection.removeAll() }
                    }
                    .accessibilityIdentifier("selection.toggle")
                }
            }
        }
    }

    private var selectedBookmarks: [Bookmark] {
        visibleBookmarks.filter { selection.contains($0.id) }
    }

    private var selectionBar: some View {
        HStack(spacing: 0) {
            Button("Favorite", systemImage: "star") {
                updateSelection { $0.isFavorite = true }
            }
            Spacer()
            Button("Unfavorite", systemImage: "star.slash") {
                updateSelection { $0.isFavorite = false }
            }
            Spacer()
            Menu {
                Button("Unfiled") { moveSelection(to: nil) }
                ForEach(collections) { collection in
                    Button(collection.name) { moveSelection(to: collection) }
                }
            } label: {
                Label("Move", systemImage: "folder")
            }
            Spacer()
            ShareLink(items: selectedBookmarks.compactMap { URL(string: $0.urlString) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Spacer()
            Button("Delete", systemImage: "trash", role: .destructive) {
                let now = Date()
                updateSelection {
                    $0.deletedAt = now
                    $0.modifiedAt = now
                }
            }
            .accessibilityIdentifier("selection.delete")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .disabled(selection.isEmpty)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        // Without a backing the icons sat on whatever card scrolled under them.
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func toggleSelection(_ bookmark: Bookmark) {
        if !selection.insert(bookmark.id).inserted {
            selection.remove(bookmark.id)
        }
    }

    private func cardOpenAction(for bookmark: Bookmark) -> (() -> Void)? {
        if isSelecting { return { toggleSelection(bookmark) } }
        return { onOpen(bookmark) }
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
            case .images:
                ContentUnavailableView(
                    "No Images",
                    systemImage: "photo",
                    description: Text("Share a screenshot or image from another app to save it here.")
                )
            case .links:
                ContentUnavailableView(
                    "No Links",
                    systemImage: "link",
                    description: Text("Share a link from another app or add one here.")
                )
            case .snippets:
                ContentUnavailableView(
                    "No Snippets",
                    systemImage: "text.quote",
                    description: Text("Save a piece of text to find it here.")
                )
            case .allItems:
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Share a link from another app or add one here.")
                )
                Button("Add Link", action: onAdd)
                    .buttonStyle(.borderedProminent)
            case .forgotten:
                ContentUnavailableView(
                    "Nothing forgotten yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Items you’ve never opened that are older than 30 days show up here.")
                )
            }
        }
        .padding()
    }
}

/// Column count and cell width derived from the grid's available width.
///
/// iPadOS windowed resize doesn't reliably re-propose width to
/// already-materialized LazyVGrid cells, leaving stale/clipped geometry
/// ("window shade" effect). Fixed columns plus an explicit card frame make
/// width an input every cell re-renders with, so cells resize in place
/// instead of the grid being torn down and rebuilt as the width changes.
private struct GridLayout {
    static let padding: CGFloat = 16
    static let minimumCellWidth: CGFloat = 160
    static let maximumCellWidth: CGFloat = 210
    #if os(macOS)
    static let spacing: CGFloat = 18
    #else
    static let spacing: CGFloat = 14
    #endif

    let columns: [GridItem]
    let cellWidth: CGFloat

    init(width: CGFloat, isAccessibilitySize: Bool) {
        let available = max(width - Self.padding * 2, 1)
        if isAccessibilitySize {
            cellWidth = available
            columns = [GridItem(.fixed(available))]
            return
        }
        let count = max(1, Int((available + Self.spacing) / (Self.minimumCellWidth + Self.spacing)))
        let fitted = (available - Self.spacing * CGFloat(count - 1)) / CGFloat(count)
        // Rounded down to whole points so neighbouring widths don't re-render
        // every cell for sub-point changes during a resize drag.
        cellWidth = min(Self.maximumCellWidth, fitted.rounded(.down))
        columns = Array(repeating: GridItem(.fixed(cellWidth), spacing: Self.spacing), count: count)
    }
}
