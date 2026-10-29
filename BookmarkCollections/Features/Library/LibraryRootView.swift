import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)])
    private var bookmarks: [Bookmark]
    @Query(sort: [SortDescriptor(\BookmarkCollection.sortPosition), SortDescriptor(\BookmarkCollection.id)])
    private var collections: [BookmarkCollection]

    @State private var destination: LibraryDestination? = .allItems
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var sort: BookmarkSort = .dateAdded
    @State private var ascending = false
    @State private var sheet: SheetDestination?
    @State private var permanentlyDeleting: Bookmark?
    @State private var emptyingRecentlyDeleted = false
    @State private var deletingCollection: BookmarkCollection?
    @State private var errorMessage: String?
    @State private var commandBookmark: Bookmark?
    #if os(macOS)
    @State private var isAddingImages = false
    #endif

    var body: some View {
        navigationView
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
            .focusedSceneValue(\.bookmarkCommandActions, commandActions)
            .onChange(of: visibleCommandBookmark?.id) { _, bookmarkID in
                if bookmarkID == nil { commandBookmark = nil }
            }
            #if os(macOS)
            .fileImporter(
                isPresented: $isAddingImages,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case let .success(urls):
                    perform {
                        let summary = try ImageImportService(context: modelContext).importImages(at: urls)
                        if !summary.failedLines.isEmpty {
                            errorMessage = "Could not add \(summary.failedLines.count) of \(urls.count) images."
                        }
                    }
                case let .failure(error):
                    errorMessage = error.localizedDescription
                }
            }
            #endif
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
                // Menu commands target the item the user last acted on, never
                // the card under the pointer.
                onEdit: { bookmark in
                    commandBookmark = bookmark
                    sheet = bookmark.kind == .text ? .snippetEditor(bookmark) : .editBookmark(bookmark)
                },
                onInfo: { bookmark in
                    commandBookmark = bookmark
                    sheet = .bookmarkInfo(bookmark)
                },
                onOpen: openBookmark,
                onPermanentDelete: { permanentlyDeleting = $0 },
                onError: { errorMessage = $0 },
                onLimitReached: { sheet = .paywall },
                onCommandSelection: { commandBookmark = $0 }
            )
            .navigationTitle(navigationTitle)
            .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Search bookmarks")
            .toolbar {
                LibraryToolbar(
                    sort: $sort,
                    ascending: $ascending,
                    onAdd: { sheet = .addBookmark },
                    onNewSnippet: { sheet = .snippetEditor(nil) },
                    onAddImages: addImages,
                    onNewCollection: { sheet = .newCollection },
                    onSettings: { sheet = .settings },
                    showEmptyRecentlyDeleted: destination == .recentlyDeleted && hasRecentlyDeletedBookmarks,
                    onEmptyRecentlyDeleted: { emptyingRecentlyDeleted = true },
                    showSurpriseMe: destination != .recentlyDeleted,
                    canSurpriseMe: hasSurpriseCandidates,
                    onSurpriseMe: surpriseMe
                )
            }
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
            AddBookmarkView(onPaywall: { sheet = .paywall })
        case let .editBookmark(bookmark):
            BookmarkEditorView(bookmark: bookmark)
        case let .bookmarkInfo(bookmark):
            BookmarkInfoView(bookmark: bookmark)
        case let .imageViewer(bookmark):
            ImageViewerView(bookmark: bookmark)
        case .newCollection:
            CollectionEditor()
        case let .editCollection(collection):
            CollectionEditor(collection: collection)
        case .settings:
            SettingsView(onPaywall: { sheet = .paywall })
        case let .shareBookmark(bookmark):
            ShareBookmarkSheet(bookmark: bookmark)
        case let .snippetEditor(bookmark):
            SnippetEditorView(bookmark: bookmark, onPaywall: { sheet = .paywall })
        case .paywall:
            PaywallView()
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

    private func addImages() {
        #if os(macOS)
        isAddingImages = true
        #endif
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            if error as? BookmarkRepository.LimitError == .limitReached {
                sheet = .paywall
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openBookmark(_ bookmark: Bookmark) {
        if bookmark.kind == .image {
            perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
            sheet = .imageViewer(bookmark)
            return
        }
        if bookmark.kind == .text {
            perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
            sheet = .snippetEditor(bookmark)
            return
        }
        guard let url = URL(string: bookmark.urlString), !bookmark.urlString.isEmpty else { return }
        perform { try BookmarkRepository(context: modelContext).markOpened(bookmark) }
        openURL(url)
    }

    private var surpriseCandidates: [Bookmark] {
        UntuckRules.surpriseCandidates(
            in: bookmarks,
            destination: destination ?? .allItems,
            searchText: searchText
        )
    }

    private var hasSurpriseCandidates: Bool {
        UntuckRules.hasSurpriseCandidates(
            in: bookmarks,
            destination: destination ?? .allItems,
            searchText: searchText
        )
    }

    private func surpriseMe() {
        guard let bookmark = surpriseCandidates.randomElement() else { return }
        openBookmark(bookmark)
    }

    private var commandActions: BookmarkCommandActions {
        // Looked up once for the flags below; the actions look it up again
        // when they run, since the selection can change in between.
        let selected = visibleCommandBookmark
        return BookmarkCommandActions(
            addLink: { sheet = .addBookmark },
            addImages: addImages,
            focusSearch: { isSearchPresented = true },
            newCollection: { sheet = .newCollection },
            newSnippet: { sheet = .snippetEditor(nil) },
            selectedBookmark: selected,
            canDeleteSelected: selected != nil && selected?.deletedAt == nil,
            openSelected: {
                guard let bookmark = visibleCommandBookmark else { return }
                openBookmark(bookmark)
            },
            shareSelected: {
                guard let bookmark = visibleCommandBookmark else { return }
                sheet = .shareBookmark(bookmark)
            },
            canCopyTextSelected: selected?.kind == .text,
            copyTextSelected: {
                guard let bookmark = visibleCommandBookmark, bookmark.kind == .text else { return }
                SnippetPasteboard.copy(bookmark.snippetBody)
            },
            deleteSelected: {
                guard let bookmark = visibleCommandBookmark,
                      bookmark.deletedAt == nil else { return }
                perform {
                    try BookmarkRepository(context: modelContext).softDelete(bookmark)
                    commandBookmark = nil
                }
            },
            surpriseMe: surpriseMe,
            canSurpriseMe: destination != .recentlyDeleted && hasSurpriseCandidates
        )
    }

    private var visibleCommandBookmark: Bookmark? {
        guard let commandBookmark,
              let bookmark = bookmarks.first(where: { $0.id == commandBookmark.id }),
              (destination ?? .allItems).matches(bookmark, searchText: searchText) else {
            return nil
        }
        return bookmark
    }
}

private enum SheetDestination: Identifiable {
    case addBookmark
    case editBookmark(Bookmark)
    case bookmarkInfo(Bookmark)
    case imageViewer(Bookmark)
    case newCollection
    case editCollection(BookmarkCollection)
    case settings
    case shareBookmark(Bookmark)
    case snippetEditor(Bookmark?)
    case paywall

    var id: String {
        switch self {
        case .addBookmark: "add-bookmark"
        case let .editBookmark(bookmark): "bookmark-\(bookmark.id)"
        case let .bookmarkInfo(bookmark): "info-\(bookmark.id)"
        case let .imageViewer(bookmark): "viewer-\(bookmark.id)"
        case .newCollection: "new-collection"
        case let .editCollection(collection): "collection-\(collection.id)"
        case .settings: "settings"
        case let .shareBookmark(bookmark): "share-\(bookmark.id)"
        case let .snippetEditor(bookmark): "snippet-\(bookmark?.id.uuidString ?? "new")"
        case .paywall: "paywall"
        }
    }
}
