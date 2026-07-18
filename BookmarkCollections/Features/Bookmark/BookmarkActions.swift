import SwiftData
import SwiftUI

struct BookmarkActions: View {
    @Environment(\.modelContext) private var modelContext
    let bookmark: Bookmark
    let isRecentlyDeleted: Bool
    let onEdit: () -> Void
    let onPermanentDelete: () -> Void
    let onError: (String) -> Void

    var body: some View {
        if isRecentlyDeleted {
            Button("Restore", systemImage: "arrow.uturn.backward") {
                perform { try BookmarkRepository(context: modelContext).restore(bookmark) }
            }
            Divider()
            Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                onPermanentDelete()
            }
        } else {
            Button(bookmark.isFavorite ? "Unfavorite" : "Favorite", systemImage: bookmark.isFavorite ? "star.slash" : "star") {
                perform {
                    try BookmarkRepository(context: modelContext).setFavorite(bookmark, to: !bookmark.isFavorite)
                }
            }
            Button("Move", systemImage: "folder") { onEdit() }
            Button("Edit", systemImage: "pencil") { onEdit() }
            ShareLink(item: URL(string: bookmark.urlString)!)
            Button("Refresh Preview", systemImage: "arrow.clockwise") {
                Task {
                    do {
                        try await MetadataEnricher(
                            context: modelContext,
                            provider: LinkPresentationMetadataProvider()
                        ).refresh(bookmark)
                    } catch {
                        onError(error.localizedDescription)
                    }
                }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                perform { try BookmarkRepository(context: modelContext).softDelete(bookmark) }
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
