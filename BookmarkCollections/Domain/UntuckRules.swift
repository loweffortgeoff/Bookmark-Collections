import Foundation

enum UntuckRules {
    static let forgottenAge: TimeInterval = 30 * 24 * 60 * 60

    static func isForgotten(_ bookmark: Bookmark, now: Date = Date()) -> Bool {
        guard bookmark.deletedAt == nil else { return false }
        guard bookmark.lastOpenedAt == nil else { return false }
        return bookmark.createdAt <= now.addingTimeInterval(-forgottenAge)
    }

    static func surpriseCandidates(
        in bookmarks: [Bookmark],
        destination: LibraryDestination,
        searchText: String
    ) -> [Bookmark] {
        bookmarks.filter { destination.matches($0, searchText: searchText) }
    }
}
