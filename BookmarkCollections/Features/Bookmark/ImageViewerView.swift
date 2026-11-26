import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Pure zoom and pan math for the image viewer. The image is fitted into the
/// viewport, then scaled; panning may only reveal the part of the scaled image
/// that overflows the viewport.
enum ImageViewerTransform {
    static let minZoom: CGFloat = 1
    static let maxZoom: CGFloat = 8

    static func fittedSize(imageSize: CGSize, in viewportSize: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              viewportSize.width > 0, viewportSize.height > 0 else { return .zero }
        let ratio = min(viewportSize.width / imageSize.width, viewportSize.height / imageSize.height)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }

    static func maxOffset(imageSize: CGSize, in viewportSize: CGSize, scale: CGFloat) -> CGSize {
        let fitted = fittedSize(imageSize: imageSize, in: viewportSize)
        guard fitted != .zero else { return .zero }
        let scale = clampedScale(scale)
        return CGSize(
            width: max(0, (fitted.width * scale - viewportSize.width) / 2),
            height: max(0, (fitted.height * scale - viewportSize.height) / 2)
        )
    }

    static func clampedOffset(_ proposed: CGSize, imageSize: CGSize, in viewportSize: CGSize, scale: CGFloat) -> CGSize {
        let limit = maxOffset(imageSize: imageSize, in: viewportSize, scale: scale)
        return CGSize(
            width: min(max(proposed.width, -limit.width), limit.width),
            height: min(max(proposed.height, -limit.height), limit.height)
        )
    }

    static func clampedScale(_ proposed: CGFloat) -> CGFloat {
        min(max(proposed, minZoom), maxZoom)
    }
}

struct ImageViewerView: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark

    @State private var zoom: CGFloat = 1
    @State private var gestureZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragTranslation: CGSize = .zero
    // Decoded once. Body runs on every pinch frame, and a decode there cost
    // a full-size image each time.
    @State private var image: Image?
    @State private var imageSize: CGSize = .zero
    @State private var didDecode = false

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    GeometryReader { proxy in
                        zoomableImage(image, viewportSize: proxy.size)
                            .onChange(of: proxy.size) { _, newSize in
                                offset = ImageViewerTransform.clampedOffset(
                                    offset, imageSize: imageSize, in: newSize, scale: zoom
                                )
                            }
                    }
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
        // Panning down while zoomed must not drag the sheet closed.
        .interactiveDismissDisabled(zoom > 1)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 400)
        #endif
        // Keyed by size so image data that syncs in later is decoded too.
        .task(id: bookmark.previewImageData?.count) {
            let decoded = decodedImage
            image = decoded?.image
            imageSize = decoded?.size ?? .zero
            didDecode = true
        }
    }

    private func zoomableImage(_ image: Image, viewportSize: CGSize) -> some View {
        let scale = ImageViewerTransform.clampedScale(zoom * gestureZoom)
        let proposed = CGSize(
            width: offset.width + dragTranslation.width,
            height: offset.height + dragTranslation.height
        )
        let effectiveOffset = ImageViewerTransform.clampedOffset(
            proposed, imageSize: imageSize, in: viewportSize, scale: scale
        )
        return image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(effectiveOffset)
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(magnifyGesture(viewportSize: viewportSize))
            .gesture(panGesture(viewportSize: viewportSize), isEnabled: zoom > 1)
            .onTapGesture(count: 2) {
                withAnimation(.snappy) {
                    if zoom > 1 {
                        zoom = 1
                        offset = .zero
                    } else {
                        zoom = 2
                        offset = ImageViewerTransform.clampedOffset(
                            offset, imageSize: imageSize, in: viewportSize, scale: 2
                        )
                    }
                    dragTranslation = .zero
                }
            }
            .accessibilityLabel(bookmark.title)
    }

    private func magnifyGesture(viewportSize: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureZoom = value.magnification
            }
            .onEnded { value in
                zoom = ImageViewerTransform.clampedScale(zoom * value.magnification)
                gestureZoom = 1
                withAnimation(.snappy) {
                    if zoom <= 1 {
                        offset = .zero
                    } else {
                        offset = ImageViewerTransform.clampedOffset(
                            offset, imageSize: imageSize, in: viewportSize, scale: zoom
                        )
                    }
                }
            }
    }

    private func panGesture(viewportSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTranslation = value.translation
            }
            .onEnded { value in
                offset = ImageViewerTransform.clampedOffset(
                    CGSize(
                        width: offset.width + value.translation.width,
                        height: offset.height + value.translation.height
                    ),
                    imageSize: imageSize,
                    in: viewportSize,
                    scale: zoom
                )
                dragTranslation = .zero
            }
    }

    private var decodedImage: (image: Image, size: CGSize)? {
        guard let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return (Image(nsImage: image), image.size)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return (Image(uiImage: image), image.size)
        #endif
    }
}
