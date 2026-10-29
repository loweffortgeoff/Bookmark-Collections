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
        guard limit > 0 else { return }
        // Only unfinished bookmarks are loaded; a large, fully enriched
        // library no longer costs a whole-store fetch on every activation.
        let ready = Bookmark.MetadataState.ready.rawValue
        let bookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(
                predicate: #Predicate { $0.metadataStateRawValue != ready },
                sortBy: [
                    SortDescriptor(\Bookmark.createdAt),
                    SortDescriptor(\Bookmark.id)
                ]
            )
        )
        let now = Date()
        // Never-fetched links come first so a library with many failures still
        // drains its new saves before retrying old ones.
        let pending = bookmarks.filter { $0.kind == .link && $0.metadataState == .pending }
        let retryable = bookmarks.filter { bookmark in
            bookmark.kind == .link
                && bookmark.metadataState == .failed
                && Self.isRetryDue(bookmark, now: now, interval: Self.failedRetryInterval)
        }

        let batch = (pending + retryable).prefix(limit)
        guard !batch.isEmpty else { return }
        // Each card observes its own bookmark, so previews still appear one
        // by one; saving once at the end spares the library a full redraw
        // per refreshed link.
        for bookmark in batch {
            await apply(to: bookmark)
        }
        try context.save()
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
        guard bookmark.kind == .link else { return }
        await apply(to: bookmark)
        try context.save()
    }

    /// Fetches and stores one link's metadata without saving the context.
    private func apply(to bookmark: Bookmark) async {
        let refreshDate = Date()
        guard let url = URL(string: bookmark.urlString) else {
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
            return
        }
        do {
            let metadata = try await provider.metadata(for: url)
            if let title = metadata.title, !title.isEmpty {
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
        } catch {
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
        }
    }
}
