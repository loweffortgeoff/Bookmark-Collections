import SwiftData
import SwiftUI

struct LibraryRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]

    @State private var destination: LibraryDestination? = .allItems
    @State private var searchText = ""
    @State private var sort: BookmarkSort = .dateAdded
    @State private var ascending = false
    @State private var sheet: SheetDestination?
    @State private var permanentlyDeleting: Bookmark?
    @State private var emptyingRecentlyDeleted = false
    @State private var deletingCollection: BookmarkCollection?
    @State private var errorMessage: String?

    var body: some View {
        navigationView
            .toolbar {
                LibraryToolbar(
                    sort: $sort,
                    ascending: $ascending,
                    onAdd: { sheet = .addBookmark },
                    onNewCollection: { sheet = .newCollection },
                    onSettings: { sheet = .settings },
                    showEmptyRecentlyDeleted: destination == .recentlyDeleted && hasRecentlyDeletedBookmarks,
                    onEmptyRecentlyDeleted: { emptyingRecentlyDeleted = true }
                )
            }
            .sheet(item: $sheet, content: sheetContent)
            .alert("Delete Permanently?", isPresented: permanentDeletePresented, presenting: permanentlyDeleting) { bookmark in
                Button("Delete Permanently", role: .destructive) {
                    perform {
                        try BookmarkRepository(context: modelContext).permanentlyDelete(bookmark)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { bookmark in
                Text("“\(bookmark.title.isEmpty ? bookmark.domain : bookmark.title)” cannot be recovered.")
            }
            .alert("Empty Recently Deleted?", isPresented: $emptyingRecentlyDeleted) {
                Button("Delete Permanently", role: .destructive) {
                    perform {
                        for bookmark in bookmarks where bookmark.deletedAt != nil {
                            modelContext.delete(bookmark)
                        }
                        try modelContext.save()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All recently deleted bookmarks will be permanently removed.")
            }
            .alert("Delete Collection?", isPresented: collectionDeletePresented, presenting: deletingCollection) { collection in
                Button("Delete Collection", role: .destructive) {
                    perform {
                        try CollectionRepository(context: modelContext).delete(collection)
                        if destination == .collection(collection.id) {
                            destination = .allItems
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { collection in
                Text("Bookmarks in “\(collection.name)” will remain in All Items.")
            }
            .alert("Couldn’t Complete Action", isPresented: errorPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Try again.")
            }
    }

    private var navigationView: some View {
        NavigationSplitView {
            CollectionListView(
                selection: $destination,
                onCreate: { sheet = .newCollection },
                onEdit: { sheet = .editCollection($0) },
                onDelete: { deletingCollection = $0 }
            )
            .navigationTitle("Bookmarks")
        } detail: {
            LibraryGridView(
                bookmarks: bookmarks,
                collections: collections,
                destination: destination ?? .allItems,
                searchText: searchText,
                sort: sort,
                ascending: ascending,
                onAdd: { sheet = .addBookmark },
                onEdit: { sheet = .editBookmark($0) },
                onPermanentDelete: { permanentlyDeleting = $0 },
                onError: { errorMessage = $0 }
            )
            .navigationTitle(navigationTitle)
            .searchable(text: $searchText, prompt: "Search bookmarks")
            .overlay(alignment: .topLeading) {
                Text(navigationTitle)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .accessibilityIdentifier((destination ?? .allItems).accessibilityIdentifier)
            }
            .overlay(alignment: .topTrailing) {
                if destination == .recentlyDeleted && hasRecentlyDeletedBookmarks {
                    Button("Empty", systemImage: "trash.slash") {
                        emptyingRecentlyDeleted = true
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .accessibilityIdentifier("recentlyDeleted.empty")
                }
            }
        }
    }

    @ViewBuilder
    private func sheetContent(for destination: SheetDestination) -> some View {
        switch destination {
        case .addBookmark:
            AddBookmarkView()
        case let .editBookmark(bookmark):
            BookmarkEditorView(bookmark: bookmark)
        case .newCollection:
            CollectionEditor()
        case let .editCollection(collection):
            CollectionEditor(collection: collection)
        case .settings:
            NavigationStack {
                ContentUnavailableView(
                    "Settings",
                    systemImage: "gear",
                    description: Text("Import, export, and iCloud status arrive in the next build step.")
                )
                .navigationTitle("Settings")
            }
        }
    }

    private var navigationTitle: String {
        guard case let .collection(id) = destination,
              let collection = collections.first(where: { $0.id == id }) else {
            return (destination ?? .allItems).title
        }
        return collection.name
    }

    private var hasRecentlyDeletedBookmarks: Bool {
        bookmarks.contains { $0.deletedAt != nil }
    }

    private var permanentDeletePresented: Binding<Bool> {
        Binding(
            get: { permanentlyDeleting != nil },
            set: { if !$0 { permanentlyDeleting = nil } }
        )
    }

    private var collectionDeletePresented: Binding<Bool> {
        Binding(
            get: { deletingCollection != nil },
            set: { if !$0 { deletingCollection = nil } }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum SheetDestination: Identifiable {
    case addBookmark
    case editBookmark(Bookmark)
    case newCollection
    case editCollection(BookmarkCollection)
    case settings

    var id: String {
        switch self {
        case .addBookmark: "add-bookmark"
        case let .editBookmark(bookmark): "bookmark-\(bookmark.id)"
        case .newCollection: "new-collection"
        case let .editCollection(collection): "collection-\(collection.id)"
        case .settings: "settings"
        }
    }
}
