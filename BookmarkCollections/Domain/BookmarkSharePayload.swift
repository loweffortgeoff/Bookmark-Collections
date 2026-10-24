import Foundation

/// Native sharing uses the locally saved content for the selected item's kind.
enum BookmarkSharePayload {
    case link(URL)
    case image(Data)
    case text(String)
    case unavailable(String)

    @MainActor
    init(bookmark: Bookmark) {
        switch bookmark.kind {
        case .link:
            if (try? NormalizedURL(bookmark.urlString)) != nil,
               let url = URL(string: bookmark.urlString) {
                self = .link(url)
            } else {
                self = .unavailable("Bookmark URL Is Invalid")
            }
        case .image:
            if let data = bookmark.previewImageData, ImageDownsampler.isValidImage(data) {
                self = .image(data)
            } else {
                self = .unavailable("Image Unavailable")
            }
        case .text:
            if (try? NormalizedURL(bookmark.urlString)) != nil,
               let url = URL(string: bookmark.urlString) {
                self = .text(bookmark.snippetBody + "\n" + url.absoluteString)
            } else {
                self = .text(bookmark.snippetBody)
            }
        }
    }
}
