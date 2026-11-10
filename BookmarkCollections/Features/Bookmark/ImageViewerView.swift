import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark

    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    // Decoded once. Body runs on every pinch frame, and a decode there cost
    // a full-size image each time.
    @State private var image: Image?
    @State private var didDecode = false

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoom * gestureZoom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    gestureZoom = value.magnification
                                }
                                .onEnded { value in
                                    zoom = min(max(zoom * value.magnification, 1), 8)
                                    gestureZoom = 1
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.snappy) {
                                zoom = zoom > 1 ? 1 : 2
                            }
                        }
                        .accessibilityLabel(bookmark.title)
                } else if didDecode {
                    ContentUnavailableView("Image Unavailable", systemImage: "photo")
                }
            }
            .navigationTitle(bookmark.title)
            .toolbarTitleDisplayMode(.inline)
            .accessibilityIdentifier("imageViewer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let image {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: image,
                            preview: SharePreview(bookmark.title, image: image)
                        )
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
        // Keyed by size so image data that syncs in later is decoded too.
        .task(id: bookmark.previewImageData?.count) {
            image = decodedImage
            didDecode = true
        }
    }

    private var decodedImage: Image? {
        guard let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }
}
