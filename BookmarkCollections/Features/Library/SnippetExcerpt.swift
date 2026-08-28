import SwiftUI

/// A snippet has no preview art, so its card shows the text instead.
struct SnippetExcerpt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineLimit(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(.quaternary)
            .accessibilityHidden(true)
    }
}
