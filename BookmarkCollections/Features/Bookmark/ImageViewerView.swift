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

    var body: some View {
        NavigationStack {
            Group {
                if let image = viewerImage {
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
                } else {
                    ContentUnavailableView("Image Unavailable", systemImage: "photo")
                }
            }
            .navigationTitle(bookmark.title)
            .accessibilityIdentifier("imageViewer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if let image = viewerImage {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: image,
                            preview: SharePreview(bookmark.title, image: image)
                        )
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    private var viewerImage: Image? {
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
