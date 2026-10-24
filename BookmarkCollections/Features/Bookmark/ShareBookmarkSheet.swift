import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Mac menu command Share destination — must always expose Cancel so the sheet can be dismissed.
struct ShareBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                sharingControl
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 260)
    }

    @ViewBuilder
    private var sharingControl: some View {
        switch BookmarkSharePayload(bookmark: bookmark) {
        case let .link(url):
            ShareLink(item: url) {
                Label("Share Bookmark", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case let .text(text):
            ShareLink(item: text) {
                Label("Share Snippet", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case let .image(data):
            if let image = shareImage(data) {
                ShareLink(item: image, preview: SharePreview(bookmark.title, image: image)) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                ContentUnavailableView("Image Unavailable", systemImage: "photo")
            }
        case let .unavailable(message):
            ContentUnavailableView {
                Label(LocalizedStringKey(message), systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func shareImage(_ data: Data) -> Image? {
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }

}
