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

    /// Every sidebar count from one walk of the library. Each bookmark is
    /// tallied under exactly the destinations whose `includes` accepts it.
    static func counts(in bookmarks: [Bookmark], now: Date = Date()) -> [LibraryDestination: Int] {
        var counts: [LibraryDestination: Int] = [:]
        for bookmark in bookmarks {
            guard bookmark.deletedAt == nil else {
                counts[.recentlyDeleted, default: 0] += 1
                continue
            }
            counts[.allItems, default: 0] += 1
            switch bookmark.kind {
            case .link: counts[.links, default: 0] += 1
            case .image: counts[.images, default: 0] += 1
            case .text: counts[.snippets, default: 0] += 1
            }
            if bookmark.isFavorite {
                counts[.favorites, default: 0] += 1
            }
            if let id = bookmark.collection?.id {
                counts[.collection(id), default: 0] += 1
            }
            if UntuckRules.isForgotten(bookmark, now: now) {
                counts[.forgotten, default: 0] += 1
            }
        }
        return counts
    }

    func matches(_ bookmark: Bookmark, searchText: String) -> Bool {
        matches(bookmark, query: Self.searchQuery(searchText))
    }

    /// Trim once per search, not once per bookmark.
    static func searchQuery(_ searchText: String) -> String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `query` must already be trimmed with `searchQuery(_:)`.
    func matches(_ bookmark: Bookmark, query: String) -> Bool {
        guard includes(bookmark) else { return false }
        guard !query.isEmpty else { return true }

        return bookmark.title.localizedCaseInsensitiveContains(query)
            || bookmark.domain.localizedCaseInsensitiveContains(query)
            || bookmark.urlString.localizedCaseInsensitiveContains(query)
            || bookmark.snippetBody.localizedCaseInsensitiveContains(query)
            || (bookmark.collection?.name.localizedCaseInsensitiveContains(query) ?? false)
    }
}
