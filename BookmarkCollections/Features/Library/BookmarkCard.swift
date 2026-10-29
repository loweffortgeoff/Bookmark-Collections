import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarkCard: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool
    let bookmark: Bookmark
    let onOpen: (() -> Void)?
    let onCommandSelection: (() -> Void)?

    init(
        bookmark: Bookmark,
        onOpen: (() -> Void)? = nil,
        onCommandSelection: (() -> Void)? = nil
    ) {
        self.bookmark = bookmark
        self.onOpen = onOpen
        self.onCommandSelection = onCommandSelection
    }

    var body: some View {
        Button {
            onCommandSelection?()
            if let onOpen {
                onOpen()
            } else if let url = URL(string: bookmark.urlString) {
                openURL(url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Fixed 16:9 canvas; the preview draws in an overlay so an
                // overflowing scaledToFill image can never stretch the card.
                Color.clear
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay { preview }
                    .clipped()

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        // Reserving a second line keeps grid rows even; the
                        // accessibility layout is one column, so it only adds a gap.
                        .lineLimit(2, reservesSpace: !dynamicTypeSize.isAccessibilitySize)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding([.horizontal, .bottom], 12)
            }
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.10 : 0.08), radius: 4, y: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused { onCommandSelection?() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(cardIdentifier)
    }

    @ViewBuilder
    private var preview: some View {
        if bookmark.kind == .text {
            SnippetExcerpt(text: bookmark.snippetBody)
        } else if let previewImage {
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

    private var subtitle: String {
        switch bookmark.kind {
        case .text:
            bookmark.domain.isEmpty ? "Snippet" : bookmark.domain
        case .image:
            bookmark.createdAt.formatted(date: .abbreviated, time: .omitted)
        case .link:
            bookmark.domain
        }
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
            snippetAccessibilityExcerpt,
            bookmark.collection?.name,
            bookmark.isFavorite ? "Favorite" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    /// `SnippetExcerpt` is `accessibilityHidden` so the card reads as one
    /// element — a snippet's body has to surface here instead, bounded so
    /// VoiceOver doesn't announce an unbounded wall of text.
    private var snippetAccessibilityExcerpt: String? {
        guard bookmark.kind == .text else { return nil }
        let trimmed = bookmark.snippetBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > 200 ? "\(trimmed.prefix(200))…" : trimmed
    }

    private var cardIdentifier: String {
        let component = URL(string: bookmark.urlString)?.lastPathComponent
        return "bookmark.\(component?.isEmpty == false ? component! : bookmark.id.uuidString)"
    }
}
