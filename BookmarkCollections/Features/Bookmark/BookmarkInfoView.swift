import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarkInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let bookmark: Bookmark
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if bookmark.kind == .link {
                    Section {
                        Button {
                            guard let url = URL(string: bookmark.urlString) else { return }
                            do {
                                try BookmarkRepository(context: modelContext).markOpened(bookmark)
                                openURL(url)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            Text(bookmark.urlString)
                                .font(.callout)
                                .foregroundStyle(.tint)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open link")
                        Button("Copy URL", systemImage: "doc.on.doc", action: copyURL)
                    }
                }
                Section {
                    Text(bookmark.title.isEmpty ? bookmark.domain : bookmark.title)
                        .font(.headline)
                }
                Section("Organization") {
                    Picker("Collection", selection: collectionSelection) {
                        Text("None").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                    Toggle("Favorite", isOn: favoriteSelection)
                }
                Section("Details") {
                    LabeledContent("Added", value: bookmark.createdAt.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Modified", value: bookmark.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Info")
            .accessibilityIdentifier("bookmarkInfo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 440)
        #endif
    }

    private var collectionSelection: Binding<UUID?> {
        Binding(
            get: { bookmark.collection?.id },
            set: { id in
                perform {
                    try BookmarkRepository(context: modelContext)
                        .move(bookmark, to: collections.first(where: { $0.id == id }))
                }
            }
        )
    }

    private var favoriteSelection: Binding<Bool> {
        Binding(
            get: { bookmark.isFavorite },
            set: { favorite in
                perform {
                    try BookmarkRepository(context: modelContext).setFavorite(bookmark, to: favorite)
                }
            }
        )
    }

    private func copyURL() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bookmark.urlString, forType: .string)
        #else
        UIPasteboard.general.string = bookmark.urlString
        #endif
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
