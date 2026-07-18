import SwiftUI

struct RecentlyDeletedView: View {
    let bookmarks: [Bookmark]
    let collections: [BookmarkCollection]
    let searchText: String
    let sort: BookmarkSort
    let ascending: Bool
    let onPermanentDelete: (Bookmark) -> Void
    let onError: (String) -> Void

    var body: some View {
        LibraryGridView(
            bookmarks: bookmarks,
            collections: collections,
            destination: .recentlyDeleted,
            searchText: searchText,
            sort: sort,
            ascending: ascending,
            onAdd: {},
            onEdit: { _ in },
            onPermanentDelete: onPermanentDelete,
            onError: onError
        )
    }
}
