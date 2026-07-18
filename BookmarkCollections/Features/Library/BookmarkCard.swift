import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarkCard: View {
    @Environment(\.openURL) private var openURL
    let bookmark: Bookmark
    let onOpen: (() -> Void)?

    init(bookmark: Bookmark, onOpen: (() -> Void)? = nil) {
        self.bookmark = bookmark
        self.onOpen = onOpen
    }

    var body: some View {
        Button {
            if let onOpen {
                onOpen()
            } else if let url = URL(string: bookmark.urlString) {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                preview
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(bookmark.domain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding([.horizontal, .bottom], 12)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(cardIdentifier)
    }

    @ViewBuilder
    private var preview: some View {
        if let previewImage {
            previewImage
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                VStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.title)
                    Text(siteInitial)
                        .font(.largeTitle.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        }
    }

    private var previewImage: Image? {
        guard let data = bookmark.previewImageData else { return nil }
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #endif
    }

    private var displayTitle: String {
        bookmark.title.isEmpty ? (bookmark.domain.isEmpty ? bookmark.urlString : bookmark.domain) : bookmark.title
    }

    private var siteInitial: String {
        String((bookmark.domain.first ?? "?")).uppercased()
    }

    private var accessibilityValue: String {
        [
            bookmark.domain,
            bookmark.collection?.name,
            bookmark.isFavorite ? "Favorite" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private var cardIdentifier: String {
        let component = URL(string: bookmark.urlString)?.lastPathComponent
        return "bookmark.\(component?.isEmpty == false ? component! : bookmark.id.uuidString)"
    }
}
