import SwiftData
import SwiftUI

/// One surface for creating, editing, and reading a snippet. A snippet has
/// nowhere else to open, so the editor is also the viewer.
struct SnippetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let bookmark: Bookmark?
    let onPaywall: () -> Void

    @State private var title = ""
    @State private var snippetBody = ""
    @State private var sourceURL = ""
    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextEditor(text: $snippetBody)
                        .frame(minHeight: 140)
                        .accessibilityLabel("Snippet text")
                }
                Section {
                    TextField("Title", text: $title, prompt: Text("Optional"))
                    TextField(
                        "Source Link",
                        text: $sourceURL,
                        prompt: Text("Optional — where this came from")
                    )
                    .textContentType(.URL)
                    Picker("Collection", selection: $selectedCollectionID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(collections) { collection in
                            Text(collection.name).tag(collection.id as UUID?)
                        }
                    }
                    Toggle("Favorite", isOn: $isFavorite)
                }
                if let openableSource {
                    Button("Open Link", systemImage: "safari") { open(openableSource) }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(bookmark == nil ? "New Snippet" : "Snippet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(snippetBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
        .accessibilityIdentifier("snippet.editor")
        .onAppear(perform: load)
    }

    /// Validated the same way saving validates it, so the button never offers
    /// to open a source link that `applySource` would silently discard.
    private var openableSource: URL? {
        let trimmed = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (try? NormalizedURL(trimmed))?.url
    }

    /// Opening the source counts as opening the snippet, on the same terms as
    /// any link, so it does not sit in Forgotten forever.
    private func open(_ url: URL) {
        if let bookmark {
            do {
                try BookmarkRepository(context: modelContext).markOpened(bookmark)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        openURL(url)
    }

    private func load() {
        guard let bookmark else { return }
        title = bookmark.title
        snippetBody = bookmark.snippetBody
        sourceURL = bookmark.urlString
        selectedCollectionID = bookmark.collection?.id
        isFavorite = bookmark.isFavorite
    }

    private func save() {
        let repository = BookmarkRepository(context: modelContext)
        let collection = collections.first { $0.id == selectedCollectionID }
        do {
            if let bookmark {
                try repository.updateSnippet(
                    bookmark,
                    title: title,
                    body: snippetBody,
                    sourceURL: sourceURL,
                    collection: collection,
                    isFavorite: isFavorite
                )
            } else {
                try repository.saveSnippet(
                    title: title,
                    body: snippetBody,
                    sourceURL: sourceURL,
                    collection: collection,
                    favorite: isFavorite
                )
            }
            dismiss()
        } catch {
            if error as? BookmarkRepository.LimitError == .limitReached {
                onPaywall()
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
