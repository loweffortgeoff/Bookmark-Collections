import Foundation

enum LibraryDestination: Hashable {
    case allItems
    case favorites
    case collection(UUID)
    case recentlyDeleted

    var title: String {
        switch self {
        case .allItems: "All Items"
        case .favorites: "Favorites"
        case .collection: "Collection"
        case .recentlyDeleted: "Recently Deleted"
        }
    }

    var systemImage: String {
        switch self {
        case .allItems: "square.grid.2x2"
        case .favorites: "star"
        case .collection: "folder"
        case .recentlyDeleted: "trash"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .allItems: "library.allItems"
        case .favorites: "library.favorites"
        case .collection: "library.collection"
        case .recentlyDeleted: "library.recentlyDeleted"
        }
    }

    func includes(_ bookmark: Bookmark) -> Bool {
        switch self {
        case .allItems:
            bookmark.deletedAt == nil
        case .favorites:
            bookmark.deletedAt == nil && bookmark.isFavorite
        case let .collection(id):
            bookmark.deletedAt == nil && bookmark.collection?.id == id
        case .recentlyDeleted:
            bookmark.deletedAt != nil
        }
    }

    func matches(_ bookmark: Bookmark, searchText: String) -> Bool {
        guard includes(bookmark) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return bookmark.title.localizedCaseInsensitiveContains(query)
            || bookmark.domain.localizedCaseInsensitiveContains(query)
            || bookmark.urlString.localizedCaseInsensitiveContains(query)
            || (bookmark.collection?.name.localizedCaseInsensitiveContains(query) ?? false)
    }
}
