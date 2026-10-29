import ImageIO
import SwiftUI

/// A bookmark's preview image, decoded off the main thread at card size and
/// cached, so scrolling and resizing the grid never re-decode the stored
/// full-size preview inside a card's `body`.
struct PreviewThumbnail<Placeholder: View>: View {
    let bookmark: Bookmark
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var entry: ThumbnailCache.Entry?

    var body: some View {
        // A stale entry for this bookmark beats a blank frame while the
        // current key decodes, so edits and cell reuse never flash.
        Group {
            switch entry ?? ThumbnailCache.shared.latest(for: bookmark.id) {
            case .image(let image)?:
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFill()
            case .missing?:
                placeholder()
            case nil:
                Rectangle().fill(.quaternary)
            }
        }
        .task(id: cacheKey) { await load() }
    }

    private func load() async {
        let id = bookmark.id
        let key = cacheKey
        if let hit = ThumbnailCache.shared.entry(for: id, key: key) {
            entry = hit
            return
        }
        guard let data = bookmark.previewImageData else {
            ThumbnailCache.shared.insert(.missing, for: id, key: key)
            entry = .missing
            return
        }
        // The decode caches its own result, so a cell that scrolls away
        // mid-decode still leaves the image ready for when it returns.
        let decoded = await Task.detached(priority: .userInitiated) {
            let decoded: ThumbnailCache.Entry = ThumbnailCache.decode(data).map { .image($0) } ?? .missing
            ThumbnailCache.shared.insert(decoded, for: id, key: key)
            return decoded
        }.value
        guard !Task.isCancelled else { return }
        entry = decoded
    }

    /// Changes whenever the stored preview can have changed. `modifiedAt`
    /// is the one stamp every preview write path sets (re-share fills a
    /// missing preview without a metadata refresh date), so unrelated edits
    /// re-decode one image while `latest(for:)` keeps the old one on screen.
    private var cacheKey: String {
        let refreshed = bookmark.lastMetadataRefreshAt?.timeIntervalSinceReferenceDate ?? 0
        return "\(bookmark.modifiedAt.timeIntervalSinceReferenceDate)-\(refreshed)"
    }
}

final class ThumbnailCache: @unchecked Sendable {
    /// A decoded preview, or a cached answer that there is none to show.
    enum Entry: @unchecked Sendable {
        case image(CGImage)
        case missing
    }

    private final class Box {
        let key: String
        let entry: Entry

        init(key: String, entry: Entry) {
            self.key = key
            self.entry = entry
        }
    }

    static let shared = ThumbnailCache()

    /// Cards top out at 210pt wide (full width at accessibility sizes);
    /// 700px covers that at 3x and most single-column iPad widths at 2x.
    static let maximumPixelSize = 700

    /// One entry per bookmark, so edits replace rather than accumulate.
    private let cache: NSCache<NSUUID, Box> = {
        let cache = NSCache<NSUUID, Box>()
        cache.countLimit = 300
        return cache
    }()

    func entry(for id: UUID, key: String) -> Entry? {
        guard let box = cache.object(forKey: id as NSUUID), box.key == key else { return nil }
        return box.entry
    }

    func latest(for id: UUID) -> Entry? {
        cache.object(forKey: id as NSUUID)?.entry
    }

    func insert(_ entry: Entry, for id: UUID, key: String) {
        cache.setObject(Box(key: key, entry: entry), forKey: id as NSUUID)
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
