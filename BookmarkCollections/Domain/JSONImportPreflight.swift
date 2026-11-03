import Foundation

/// Projects only the fields that affect capacity, without touching SwiftData.
@MainActor
enum JSONImportPreflight {
    private struct Item {
        let id: UUID
        let kind: Bookmark.Kind
        let normalizedURL: String
        let createdAt: Date
        let deletedAt: Date?
    }

    static func assertCanImport(_ document: BackupDocument, existingBookmarks: [Bookmark]) throws {
        guard PaywallConfiguration.isEnforced, !PurchaseAccess.isUnlocked else { return }
        var items = Dictionary(uniqueKeysWithValues: existingBookmarks.map { bookmark in
            (bookmark.id, Item(id: bookmark.id, kind: bookmark.kind,
                               normalizedURL: bookmark.normalizedURLString,
                               createdAt: bookmark.createdAt, deletedAt: bookmark.deletedAt))
        })
        let activeCount = reconciledActiveCount(items)

        // Mirror import order and identity rules: valid links update by ID without
        // changing an existing item's kind; snippets cannot overwrite another kind.
        for record in document.bookmarks {
            guard let normalized = try? NormalizedURL(record.urlString) else { continue }
            items[record.id] = Item(id: record.id, kind: items[record.id]?.kind ?? .link,
                                    normalizedURL: normalized.string,
                                    createdAt: record.createdAt, deletedAt: record.deletedAt)
        }
        for record in document.snippets {
            guard !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if let existing = items[record.id], existing.kind != .text { continue }
            items[record.id] = Item(id: record.id, kind: .text, normalizedURL: "",
                                    createdAt: record.createdAt, deletedAt: record.deletedAt)
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
        var canonicalLinks: [String: Item] = [:]
        for item in items.values {
            guard item.kind == .link, !item.normalizedURL.isEmpty else {
                if item.deletedAt == nil { activeCount += 1 }
                continue
            }

            // BookmarkRepository.reconcileDuplicates keeps the earliest-created
            // link (UUID breaks ties), including that canonical link's deletedAt.
            if let canonical = canonicalLinks[item.normalizedURL] {
                let precedes = item.createdAt < canonical.createdAt ||
                    (item.createdAt == canonical.createdAt && item.id.uuidString < canonical.id.uuidString)
                if precedes { canonicalLinks[item.normalizedURL] = item }
            } else {
                canonicalLinks[item.normalizedURL] = item
            }
        }
        return activeCount + canonicalLinks.values.lazy.filter { $0.deletedAt == nil }.count
    }
}
