import SwiftUI

#if os(iOS)
import UIKit
private typealias PlatformImage = UIImage
#elseif os(macOS)
import AppKit
private typealias PlatformImage = NSImage
#endif

struct ShareCapturePreview: View {
    let kind: Bookmark.Kind
    let snippetBody: String
    let urlString: String
    let suggestedTitle: String?
    let previewImageData: Data?

    var body: some View {
        Section {
            if kind == .text {
                Text(snippetBody)
                    .textSelection(.enabled)
                if !urlString.isEmpty {
                    LabeledContent("Source link") {
                        Text(urlString)
                            .textSelection(.enabled)
                    }
                }
            } else {
                if let previewData = previewImageData,
                   let preview = PlatformImage(data: previewData) {
                    Image(platformImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                }
                if let title = suggestedTitle, !title.isEmpty {
                    LabeledContent("Title", value: title)
                }
                if kind == .link {
                    Text(urlString)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }
        } header: {
            switch kind {
            case .text: Text("Snippet")
            case .image: Text("Image")
            case .link: Text("Link")
            }
        }
    }
}

private extension Image {
    init(platformImage: PlatformImage) {
        #if os(iOS)
        self.init(uiImage: platformImage)
        #elseif os(macOS)
        self.init(nsImage: platformImage)
        #endif
    }
}
