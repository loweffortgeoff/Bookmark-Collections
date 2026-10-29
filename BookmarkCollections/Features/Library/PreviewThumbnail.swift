import ImageIO
import SwiftUI

/// A bookmark's preview image, decoded off the main thread at card size and
/// cached, so scrolling and resizing the grid never re-decode the stored
/// full-size preview inside a card's `body`.
struct PreviewThumbnail<Placeholder: View>: View {
    let bookmark: Bookmark
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: CGImage?
    @State private var hasNoPreview = false

    var body: some View {
        let key = cacheKey
        let cached = image ?? ThumbnailCache.shared.image(for: key)
        Group {
            if let cached {
                Image(decorative: cached, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else if hasNoPreview {
                placeholder()
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: key) {
            if let hit = ThumbnailCache.shared.image(for: key) {
                image = hit
                return
            }
            guard let data = bookmark.previewImageData else {
                image = nil
                hasNoPreview = true
                return
            }
            hasNoPreview = false
            let decoded = await Task.detached(priority: .userInitiated) {
                DecodedImage(image: ThumbnailCache.decode(data))
            }.value.image
            guard !Task.isCancelled else { return }
            if let decoded { ThumbnailCache.shared.insert(decoded, for: key) }
            image = decoded
        }
    }

    /// Changes whenever the stored preview can have changed: metadata
    /// refreshes and edits both stamp one of these dates.
    private var cacheKey: String {
        let refreshed = bookmark.lastMetadataRefreshAt?.timeIntervalSinceReferenceDate ?? 0
        return "\(bookmark.id.uuidString)-\(bookmark.modifiedAt.timeIntervalSinceReferenceDate)-\(refreshed)"
    }
}

/// Carries a decoded image out of the detached decode task.
private struct DecodedImage: @unchecked Sendable {
    let image: CGImage?
}

final class ThumbnailCache: @unchecked Sendable {
    static let shared = ThumbnailCache()

    /// Cards top out at 210pt wide (full width at accessibility sizes);
    /// 700px covers that at 3x and most single-column iPad widths at 2x.
    static let maximumPixelSize = 700

    private let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.countLimit = 300
        return cache
    }()

    func image(for key: String) -> CGImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: CGImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
