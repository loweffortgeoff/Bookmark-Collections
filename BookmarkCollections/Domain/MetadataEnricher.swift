import Foundation
import SwiftData

@MainActor
struct MetadataEnricher {
    /// A failed link is retried only after this delay, so a broken URL is not
    /// refetched on every scene activation.
    static let failedRetryInterval: TimeInterval = 60 * 60

    let context: ModelContext
    let provider: any MetadataProviding

    func enrichPending(limit: Int, includePending: Bool = true) async throws {
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
        let pending = includePending ? bookmarks.filter(Self.isActivePendingLink) : []
        let retryable = bookmarks.filter { bookmark in
            Self.isActiveLink(bookmark)
                && bookmark.metadataState == .failed
                && Self.isRetryDue(bookmark, now: now, interval: Self.failedRetryInterval)
        }

        let batch = (pending + retryable).prefix(limit)
        // Keep completed results if cancellation interrupts a later fetch.
        for bookmark in batch {
            if try await apply(to: bookmark) {
                try context.save()
            }
        }
    }

    /// Enrich only the pending record that keys the library's SwiftUI task.
    func enrichPendingBookmark(id: PersistentIdentifier) async throws {
        try Task.checkCancellation()
        var descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.persistentModelID == id }
        )
        descriptor.fetchLimit = 1
        guard let bookmark = try context.fetch(descriptor).first,
              Self.isActivePendingLink(bookmark) else { return }
        try await refresh(bookmark)
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

    static func isActivePendingLink(_ bookmark: Bookmark) -> Bool {
        isActiveLink(bookmark) && bookmark.metadataState == .pending
    }

    private static func isActiveLink(_ bookmark: Bookmark) -> Bool {
        bookmark.modelContext != nil && !bookmark.isDeleted
            && bookmark.deletedAt == nil && bookmark.kind == .link
    }

    private func canApply(to bookmark: Bookmark, previousRefreshAt: Date?, requestedURL: String) throws -> Bool {
        guard Self.isActiveLink(bookmark),
              bookmark.lastMetadataRefreshAt == previousRefreshAt,
              bookmark.urlString == requestedURL else { return false }
        // Another context can delete the stored row while this model still
        // has a context and reports isDeleted == false.
        let id = bookmark.persistentModelID
        return try context.fetchCount(FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.persistentModelID == id }
        )) > 0
    }

    /// Returns whether metadata was applied and needs saving.
    private func apply(to bookmark: Bookmark) async throws -> Bool {
        try Task.checkCancellation()
        guard Self.isActiveLink(bookmark) else { return false }
        let previousRefreshAt = bookmark.lastMetadataRefreshAt
        let requestedURL = bookmark.urlString
        let refreshDate = Date()
        guard let url = URL(string: requestedURL) else {
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
            return true
        }
        let metadata: LinkMetadata
        do {
            metadata = try await provider.metadata(for: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            guard try canApply(to: bookmark, previousRefreshAt: previousRefreshAt, requestedURL: requestedURL) else { return false }
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
            return true
        }
        try Task.checkCancellation()
        guard try canApply(to: bookmark, previousRefreshAt: previousRefreshAt, requestedURL: requestedURL) else { return false }
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
        return true
    }
}
