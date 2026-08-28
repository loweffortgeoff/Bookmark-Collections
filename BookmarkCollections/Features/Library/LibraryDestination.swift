import Foundation

enum LibraryDestination: Hashable {
    case allItems
    case favorites
    case links
    case images
    case snippets
    case collection(UUID)
    case forgotten
    case recentlyDeleted

    var title: String {
        switch self {
        case .allItems: "All Items"
        case .favorites: "Favorites"
        case .links: "Links"
        case .images: "Images"
        case .snippets: "Snippets"
        case .collection: "Collection"
        case .forgotten: "Forgotten"
        case .recentlyDeleted: "Recently Deleted"
        }
    }

    var systemImage: String {
        switch self {
        case .allItems: "square.grid.2x2"
        case .favorites: "star"
        case .links: "link"
        case .images: "photo"
        case .snippets: "text.quote"
        case .collection: "folder"
        case .forgotten: "clock.arrow.circlepath"
        case .recentlyDeleted: "trash"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .allItems: "library.allItems"
        case .favorites: "library.favorites"
        case .links: "library.links"
        case .images: "library.images"
        case .snippets: "library.snippets"
        case .collection: "library.collection"
        case .forgotten: "library.forgotten"
        case .recentlyDeleted: "library.recentlyDeleted"
        }
    }

    func includes(_ bookmark: Bookmark) -> Bool {
        switch self {
        case .allItems:
            bookmark.deletedAt == nil
        case .favorites:
            bookmark.deletedAt == nil && bookmark.isFavorite
        case .links:
            bookmark.deletedAt == nil && bookmark.kind == .link
        case .images:
            bookmark.deletedAt == nil && bookmark.kind == .image
        case .snippets:
            bookmark.deletedAt == nil && bookmark.kind == .text
        case let .collection(id):
            bookmark.deletedAt == nil && bookmark.collection?.id == id
        case .forgotten:
            UntuckRules.isForgotten(bookmark)
        case .recentlyDeleted:
            bookmark.deletedAt != nil
        }
    }

    func count(in bookmarks: [Bookmark]) -> Int {
        bookmarks.filter { includes($0) }.count
    }

    func matches(_ bookmark: Bookmark, searchText: String) -> Bool {
        guard includes(bookmark) else { return false }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return bookmark.title.localizedCaseInsensitiveContains(query)
            || bookmark.domain.localizedCaseInsensitiveContains(query)
            || bookmark.urlString.localizedCaseInsensitiveContains(query)
            || bookmark.snippetBody.localizedCaseInsensitiveContains(query)
            || (bookmark.collection?.name.localizedCaseInsensitiveContains(query) ?? false)
    }
}
