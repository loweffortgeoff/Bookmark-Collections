import Foundation

enum LibraryDestination: Hashable {
    case allItems
    case favorites
    case collection(UUID)
    case recentlyDeleted

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

