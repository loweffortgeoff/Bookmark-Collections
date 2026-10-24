import SwiftUI

/// Mac menu command Share destination — must always expose Cancel so the sheet can be dismissed.
struct ShareBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bookmark: Bookmark

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                if let url = URL(string: bookmark.urlString) {
                    ShareLink(item: url) {
                        Label("Share Bookmark", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    ContentUnavailableView(
                        "Bookmark URL Is Invalid",
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
            .navigationTitle("Share")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 260)
    }
}
