import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarkActions: View {
    @Environment(\.modelContext) private var modelContext
    let bookmark: Bookmark
    let isRecentlyDeleted: Bool
    let onEdit: () -> Void
    let onInfo: () -> Void
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
            Button("Get Info", systemImage: "info.circle") { onInfo() }
            Button(bookmark.isFavorite ? "Unfavorite" : "Favorite", systemImage: bookmark.isFavorite ? "star.slash" : "star") {
                perform {
                    try BookmarkRepository(context: modelContext).setFavorite(bookmark, to: !bookmark.isFavorite)
                }
            }
            Button("Move", systemImage: "folder") { onEdit() }
            Button("Edit", systemImage: "pencil") { onEdit() }
            if bookmark.kind == .text {
                Button("Copy Text", systemImage: "doc.on.doc") {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bookmark.snippetBody, forType: .string)
                    #else
                    UIPasteboard.general.string = bookmark.snippetBody
                    #endif
                }
            }
            if bookmark.kind == .link {
                ShareLink(item: URL(string: bookmark.urlString)!)
            } else if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview(bookmark.title, image: shareImage))
            }
            if bookmark.kind == .link {
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

    private var shareImage: Image? {
        guard bookmark.kind == .image, let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }
}
