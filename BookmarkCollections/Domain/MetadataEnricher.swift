import Foundation
import SwiftData

@MainActor
struct MetadataEnricher {
    /// A failed link is retried only after this delay, so a broken URL is not
    /// refetched on every scene activation.
    static let failedRetryInterval: TimeInterval = 60 * 60

    let context: ModelContext
    let provider: any MetadataProviding

    func enrichPending(limit: Int) async throws {
        try Task.checkCancellation()
        guard limit > 0 else { return }
        // Only unfinished bookmarks are loaded; a large, fully enriched
        // library no longer costs a whole-store fetch on every activation.
        let ready = Bookmark.MetadataState.ready.rawValue
        let bookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(
                predicate: #Predicate { $0.metadataStateRawValue != ready && $0.deletedAt == nil },
                sortBy: [
                    SortDescriptor(\Bookmark.createdAt),
                    SortDescriptor(\Bookmark.id)
                ]
            )
        )
        let now = Date()
        // Never-fetched links come first so a library with many failures still
        // drains its new saves before retrying old ones.
        let pending = bookmarks.filter { isActiveLink($0) && $0.metadataState == .pending }
        let retryable = bookmarks.filter { bookmark in
            isActiveLink(bookmark)
                && bookmark.metadataState == .failed
                && Self.isRetryDue(bookmark, now: now, interval: Self.failedRetryInterval)
        }

        let batch = (pending + retryable).prefix(limit)
        // A pending-count change can cancel this batch. Save each completed
        // result before the next fetch can suspend or the task can restart.
        for bookmark in batch {
            if try await apply(to: bookmark) {
                try context.save()
            }
        }
    }

    private static func isRetryDue(
        _ bookmark: Bookmark,
        now: Date,
        interval: TimeInterval
    ) -> Bool {
        guard let lastAttempt = bookmark.lastMetadataRefreshAt else { return true }
        return now.timeIntervalSince(lastAttempt) >= interval
    }

    func refresh(_ bookmark: Bookmark) async throws {
        if try await apply(to: bookmark) {
            try context.save()
        }
    }

    private func isActiveLink(_ bookmark: Bookmark) -> Bool {
        bookmark.modelContext != nil && !bookmark.isDeleted
            && bookmark.deletedAt == nil && bookmark.kind == .link
    }

    /// Returns whether metadata was applied and needs saving.
    private func apply(to bookmark: Bookmark) async throws -> Bool {
        try Task.checkCancellation()
        guard isActiveLink(bookmark) else { return false }
        let refreshDate = Date()
        guard let url = URL(string: bookmark.urlString) else {
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
            return true
        }
        do {
            let metadata = try await provider.metadata(for: url)
            try Task.checkCancellation()
            guard isActiveLink(bookmark) else { return false }
            // A title the user typed, or one restored from an import, wins
            // over the page's own title.
            if bookmark.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let title = metadata.title, !title.isEmpty {
                bookmark.title = title
            }
            if !metadata.domain.isEmpty {
                bookmark.domain = metadata.domain
            }
            // A fetch can succeed without an image (many pages have no
            // og:image). Keep any preview already stored instead of erasing it.
            if let faviconData = metadata.faviconData {
                bookmark.faviconData = faviconData
            }
            if let previewImageData = metadata.previewImageData {
                bookmark.previewImageData = previewImageData
            }
            bookmark.metadataState = .ready
            bookmark.lastMetadataRefreshAt = refreshDate
            bookmark.modifiedAt = refreshDate
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            guard isActiveLink(bookmark) else { return false }
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
        }
        return true
    }
}
