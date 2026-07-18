import Foundation
import SwiftData

@MainActor
struct MetadataEnricher {
    let context: ModelContext
    let provider: any MetadataProviding

    func enrichPending(limit: Int) async throws {
        guard limit > 0 else { return }
        let bookmarks = try context.fetch(
            FetchDescriptor<Bookmark>(sortBy: [
                SortDescriptor(\Bookmark.createdAt),
                SortDescriptor(\Bookmark.id)
            ])
        )
        let pending = bookmarks.lazy.filter { $0.metadataState == .pending }.prefix(limit)

        for bookmark in pending {
            try await refresh(bookmark)
        }
    }

    func refresh(_ bookmark: Bookmark) async throws {
        let refreshDate = Date()
        do {
            guard let url = URL(string: bookmark.urlString) else {
                bookmark.metadataState = .failed
                bookmark.lastMetadataRefreshAt = refreshDate
                try context.save()
                return
            }
            let metadata = try await provider.metadata(for: url)
            if let title = metadata.title, !title.isEmpty {
                bookmark.title = title
            }
            if !metadata.domain.isEmpty {
                bookmark.domain = metadata.domain
            }
            bookmark.faviconData = metadata.faviconData
            bookmark.previewImageData = metadata.previewImageData
            bookmark.metadataState = .ready
            bookmark.lastMetadataRefreshAt = refreshDate
            bookmark.modifiedAt = refreshDate
        } catch {
            bookmark.metadataState = .failed
            bookmark.lastMetadataRefreshAt = refreshDate
        }
        try context.save()
    }
}

