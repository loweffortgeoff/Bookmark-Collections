import Foundation
import SwiftData

enum SaveResult {
    case created(Bookmark)
    case updated(Bookmark)
    case restored(Bookmark)
}

extension BookmarkRepository {
    enum LimitError: Swift.Error, LocalizedError, Equatable {
        case limitReached

        var errorDescription: String? {
            "You can save up to 10 bookmarks free. Unlock Tucked for Life to save more."
        }
    }

    enum SnippetError: Swift.Error, LocalizedError, Equatable {
        case emptyBody
        case notASnippet

        var errorDescription: String? {
            switch self {
            case .emptyBody: "A snippet needs some text."
            case .notASnippet: "That bookmark is not a snippet."
            }
        }
    }
}

@MainActor
struct BookmarkRepository {
    let context: ModelContext
    let isUnlocked: Bool
    let paywallEnabled: Bool

    init(
        context: ModelContext,
        isUnlocked: Bool = PurchaseAccess.isUnlocked,
        paywallEnabled: Bool = PaywallConfiguration.isEnabled
    ) {
        self.context = context
        self.isUnlocked = isUnlocked
        self.paywallEnabled = paywallEnabled
    }

    func save(
        url value: String,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> SaveResult {
        try saveLink(url: value, collection: collection, favorite: favorite)
    }

    /// Share capture may preserve organization while normal editor/import saves keep explicit defaults.
    func saveSharedLink(
        url: String,
        collection: BookmarkCollection?,
        favorite: Bool,
        preserveOrganization: Bool,
        suggestedTitle: String?,
        faviconData: Data?,
        previewImageData: Data?,
        metadataWasFetched: Bool
    ) throws -> SaveResult {
        try saveLink(
            url: url, collection: collection, favorite: favorite,
            preserveOrganization: preserveOrganization
        ) { bookmark in
            if bookmark.title.isEmpty, let suggestedTitle, !suggestedTitle.isEmpty {
                bookmark.title = suggestedTitle
            }
            if bookmark.faviconData == nil { bookmark.faviconData = faviconData }
            if bookmark.previewImageData == nil { bookmark.previewImageData = previewImageData }
            if metadataWasFetched {
                bookmark.metadataState = .ready
                bookmark.lastMetadataRefreshAt = Date()
            }
        }
    }

    func sharedLinkMatch(url: String) throws -> Bookmark? {
        let normalizedString = try NormalizedURL(url).string
        let matches = try context.fetch(FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.normalizedURLString == normalizedString },
            sortBy: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)]
        ))
        return matches.first(where: { $0.deletedAt == nil }) ?? matches.first
    }

    private func saveLink(
        url value: String,
        collection: BookmarkCollection?,
        favorite: Bool,
        preserveOrganization: Bool = false,
        prepare: (Bookmark) -> Void = { _ in }
    ) throws -> SaveResult {
        let normalized = try NormalizedURL(value)
        let normalizedString = normalized.string
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.normalizedURLString == normalizedString
            },
            sortBy: [SortDescriptor(\Bookmark.createdAt), SortDescriptor(\Bookmark.id)]
        )
        let matches = try context.fetch(descriptor)
        let now = Date()

        let result: SaveResult
        if let existing = matches.first(where: { $0.deletedAt == nil }) {
            if !preserveOrganization {
                existing.collection = collection
                existing.isFavorite = favorite
            }
            existing.modifiedAt = now
            result = .updated(existing)
        } else if let deleted = matches.first {
            try assertCanCreate()
            deleted.deletedAt = nil
            if !preserveOrganization {
                deleted.collection = collection
                deleted.isFavorite = favorite
            }
            deleted.modifiedAt = now
            result = .restored(deleted)
        } else {
            try assertCanCreate()
            let bookmark = Bookmark(
                urlString: value,
                normalizedURLString: normalizedString,
                createdAt: now
            )
            bookmark.domain = normalized.url.host?.lowercased() ?? ""
            bookmark.collection = collection
            bookmark.isFavorite = favorite
            bookmark.metadataState = .pending
            context.insert(bookmark)
            result = .created(bookmark)
        }

        switch result {
        case let .created(bookmark), let .updated(bookmark), let .restored(bookmark):
            prepare(bookmark)
        }
        try context.save()
        return result
    }

    @discardableResult
    func saveImage(
        data: Data,
        title: String,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> Bookmark {
        try assertCanCreate()
        let now = Date()
        let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: now)
        bookmark.kind = .image
        bookmark.title = title
        bookmark.previewImageData = data
        bookmark.collection = collection
        bookmark.isFavorite = favorite
        bookmark.metadataState = .ready
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    /// Fall back to the snippet's first meaningful line when no title was given.
    static func deriveSnippetTitle(_ title: String, body: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let firstLine = body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
        if firstLine.isEmpty { return "Snippet" }
        return firstLine.count > 80 ? "\(firstLine.prefix(80))…" : firstLine
    }

    @discardableResult
    func saveSnippet(
        title: String = "",
        body: String,
        sourceURL: String? = nil,
        collection: BookmarkCollection? = nil,
        favorite: Bool = false
    ) throws -> Bookmark {
        try assertCanCreate()
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw SnippetError.emptyBody }

        let now = Date()
        // A snippet keeps an empty normalized URL so link de-duplication,
        // which always queries with a parsed NormalizedURL, can never match it.
        let bookmark = Bookmark(urlString: "", normalizedURLString: "", createdAt: now)
        bookmark.kind = .text
        bookmark.snippetBody = trimmedBody
        bookmark.title = Self.deriveSnippetTitle(title, body: trimmedBody)
        Self.applySource(sourceURL, to: bookmark)
        bookmark.collection = collection
        bookmark.isFavorite = favorite
        bookmark.metadataState = .ready
        context.insert(bookmark)
        try context.save()
        return bookmark
    }

    func updateSnippet(
        _ bookmark: Bookmark,
        title: String,
        body: String,
        sourceURL: String?,
        collection: BookmarkCollection?,
        isFavorite: Bool
    ) throws {
        guard bookmark.kind == .text else { throw SnippetError.notASnippet }
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else { throw SnippetError.emptyBody }

        bookmark.snippetBody = trimmedBody
        bookmark.title = Self.deriveSnippetTitle(title, body: trimmedBody)
        Self.applySource(sourceURL, to: bookmark)
        bookmark.collection = collection
        bookmark.isFavorite = isFavorite
        bookmark.modifiedAt = Date()
        try context.save()
    }

    /// A snippet's source link is optional, so an unparseable one is dropped
    /// rather than costing the user the text they were trying to keep.
    static func applySource(_ sourceURL: String?, to bookmark: Bookmark) {
        let trimmed = sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, let normalized = try? NormalizedURL(trimmed) else {
            bookmark.urlString = ""
            bookmark.domain = ""
            return
        }
        bookmark.urlString = trimmed
        bookmark.domain = normalized.url.host?.lowercased() ?? ""
    }

    func reconcileDuplicates() throws {
        // The empty check is not redundant with the kind filter. A build that
        // predates a kind maps that unknown raw value to `.link`, so a synced
        // snippet arrives here looking like a link. Every such record shares an
        // empty normalized URL, so grouping would treat them all as duplicates
        // of one another and hard-delete every one but the oldest. Only records
        // with a real normalized URL can ever be link duplicates.
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
            .filter { $0.kind == .link && !$0.normalizedURLString.isEmpty }
        let groups = Dictionary(grouping: bookmarks, by: \Bookmark.normalizedURLString)
        var changed = false

        for group in groups.values where group.count > 1 {
            let orderedByCreation = group.sorted { left, right in
                if left.createdAt == right.createdAt {
                    return left.id.uuidString < right.id.uuidString
                }
                return left.createdAt < right.createdAt
            }
            guard let canonical = orderedByCreation.first else { continue }
            let mostRecentlyModified = group.max { left, right in
                if left.modifiedAt == right.modifiedAt {
                    return left.id.uuidString < right.id.uuidString
                }
                return left.modifiedAt < right.modifiedAt
            } ?? canonical

            canonical.isFavorite = group.contains(where: \Bookmark.isFavorite)
            canonical.title = mostRecentlyModified.title
            canonical.collection = mostRecentlyModified.collection
            canonical.modifiedAt = mostRecentlyModified.modifiedAt
            canonical.lastOpenedAt = group.compactMap(\.lastOpenedAt).max()

            for duplicate in orderedByCreation.dropFirst() {
                context.delete(duplicate)
            }
            changed = true
        }

        if changed {
            try context.save()
        }
    }

    func markOpened(_ bookmark: Bookmark, at date: Date = Date()) throws {
        bookmark.lastOpenedAt = date
        bookmark.modifiedAt = date
        try context.save()
    }

    func setFavorite(_ bookmark: Bookmark, to isFavorite: Bool) throws {
        bookmark.isFavorite = isFavorite
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func move(_ bookmark: Bookmark, to collection: BookmarkCollection?) throws {
        bookmark.collection = collection
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func softDelete(_ bookmark: Bookmark, at date: Date = Date()) throws {
        bookmark.deletedAt = date
        bookmark.modifiedAt = date
        try context.save()
    }

    func restore(_ bookmark: Bookmark) throws {
        try assertCanCreate()
        bookmark.deletedAt = nil
        bookmark.modifiedAt = Date()
        try context.save()
    }

    func permanentlyDelete(_ bookmark: Bookmark) throws {
        context.delete(bookmark)
        try context.save()
    }

    @discardableResult
    func purgeExpiredDeleted(now: Date = Date()) throws -> Int {
        let expirationDate = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        let expired = bookmarks.filter { bookmark in
            guard let deletedAt = bookmark.deletedAt else { return false }
            return deletedAt < expirationDate
        }
        for bookmark in expired {
            context.delete(bookmark)
        }
        if !expired.isEmpty {
            try context.save()
        }
        return expired.count
    }

    private func assertCanCreate() throws {
        guard paywallEnabled else { return }
        let bookmarks = try context.fetch(FetchDescriptor<Bookmark>())
        let activeBookmarkCount = bookmarks.lazy.filter { $0.deletedAt == nil }.count
        guard BookmarkLimit.canCreate(activeBookmarkCount: activeBookmarkCount, isUnlocked: isUnlocked) else {
            throw LimitError.limitReached
        }
    }
}
