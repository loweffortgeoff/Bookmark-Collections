import SwiftData
import SwiftUI

struct BookmarkEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let bookmark: Bookmark
    @State private var title: String
    @State private var selectedCollectionID: UUID?
    @State private var isFavorite: Bool
    @State private var errorMessage: String?

    init(bookmark: Bookmark) {
        self.bookmark = bookmark
        _title = State(initialValue: bookmark.title)
        _selectedCollectionID = State(initialValue: bookmark.collection?.id)
        _isFavorite = State(initialValue: bookmark.isFavorite)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                LabeledContent("URL", value: bookmark.urlString)
                CollectionPicker(collections: collections, selection: $selectedCollectionID)
                Toggle("Favorite", isOn: $isFavorite)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Bookmark")
            .accessibilityIdentifier("bookmarkEditor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 280)
        #endif
    }

    private func save() {
        bookmark.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        bookmark.collection = collections.first(where: { $0.id == selectedCollectionID })
        bookmark.isFavorite = isFavorite
        bookmark.modifiedAt = Date()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
