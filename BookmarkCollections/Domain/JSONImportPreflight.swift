import Foundation

/// Projects only the fields that affect capacity, without touching SwiftData.
@MainActor
enum JSONImportPreflight {
    private struct Item {
        let kind: Bookmark.Kind
        let normalizedURL: String
        let deletedAt: Date?
        let modifiedAt: Date
    }

    static func assertCanImport(_ document: BackupDocument, existingBookmarks: [Bookmark]) throws {
        guard PaywallConfiguration.isEnforced, !PurchaseAccess.isUnlocked else { return }
        // Equal-id records can exist after an import runs on two devices before
        // sync. Keep the active one so it still counts toward the cap.
        var items = Dictionary(existingBookmarks.map { bookmark in
            (bookmark.id, Item(kind: bookmark.kind, normalizedURL: bookmark.normalizedURLString,
                               deletedAt: bookmark.deletedAt, modifiedAt: bookmark.modifiedAt))
        }, uniquingKeysWith: { first, second in
            first.deletedAt == nil || second.deletedAt != nil ? first : second
        })
        let activeCount = reconciledActiveCount(items)

        // Mirror import order and identity rules: links and snippets cannot
        // overwrite another kind, even when the backup has a newer date.
        // Keep newer dates from the library and from earlier records in this file.
        for record in document.bookmarks {
            guard let normalized = try? NormalizedURL(record.urlString) else { continue }
            if let existing = items[record.id], existing.kind != .link { continue }
            if let existing = items[record.id], existing.modifiedAt > record.modifiedAt { continue }
            items[record.id] = Item(kind: .link,
                                    normalizedURL: normalized.string, deletedAt: record.deletedAt,
                                    modifiedAt: record.modifiedAt)
        }
        for record in document.snippets {
            guard !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if let existing = items[record.id], existing.kind != .text { continue }
            if let existing = items[record.id], existing.modifiedAt > record.modifiedAt { continue }
            items[record.id] = Item(kind: .text, normalizedURL: "", deletedAt: record.deletedAt,
                                    modifiedAt: record.modifiedAt)
        }

        let finalActiveCount = reconciledActiveCount(items)

        // Compare reconciled counts on both sides so pre-existing sync duplicates
        // cannot hide genuine growth beyond the free cap.
        guard finalActiveCount > activeCount else { return }
        guard BookmarkLimit.canCreate(activeBookmarkCount: finalActiveCount - 1, isUnlocked: false) else {
            throw BookmarkRepository.LimitError.limitReached
        }
    }

    private static func reconciledActiveCount(_ items: [UUID: Item]) -> Int {
        var activeCount = 0
        var activeLinkURLs: Set<String> = []
        for item in items.values {
            guard item.kind == .link, !item.normalizedURL.isEmpty else {
                if item.deletedAt == nil { activeCount += 1 }
                continue
            }

            // Preflight counts one slot per URL when any copy is active.
            // Reconciliation keeps indistinguishable clones (same id and
            // createdAt), so this can undercount visible clone pairs.
            if item.deletedAt == nil { activeLinkURLs.insert(item.normalizedURL) }
        }
        return activeCount + activeLinkURLs.count
    }
}
