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
        let query = LibraryDestination.searchQuery(searchText)
        return bookmarks.filter { destination.matches($0, query: query) }
    }

    /// Whether Surprise Me has anything to pick, stopping at the first match
    /// instead of building the full candidate list on every redraw.
    static func hasSurpriseCandidates(
        in bookmarks: [Bookmark],
        destination: LibraryDestination,
        searchText: String
    ) -> Bool {
        let query = LibraryDestination.searchQuery(searchText)
        return bookmarks.contains { destination.matches($0, query: query) }
    }
}
