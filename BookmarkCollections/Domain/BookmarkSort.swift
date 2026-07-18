import Foundation

enum BookmarkSort: String, CaseIterable, Identifiable {
    case dateAdded
    case dateModified
    case title
    case domain

    var id: String { rawValue }

    func descriptors(ascending: Bool) -> [SortDescriptor<Bookmark>] {
        let order: SortOrder = ascending ? .forward : .reverse
        let primary: SortDescriptor<Bookmark>

        switch self {
        case .dateAdded:
            primary = SortDescriptor(\Bookmark.createdAt, order: order)
        case .dateModified:
            primary = SortDescriptor(\Bookmark.modifiedAt, order: order)
        case .title:
            primary = SortDescriptor(\Bookmark.title, order: order)
        case .domain:
            primary = SortDescriptor(\Bookmark.domain, order: order)
        }

        return [primary, SortDescriptor(\Bookmark.id)]
    }
}

