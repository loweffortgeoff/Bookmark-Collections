import SwiftData
import SwiftUI

struct AddBookmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    let onPaywall: () -> Void

    @State private var urlString = ""
    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Web Address", text: $urlString, prompt: Text("https://example.com"))
                    .textContentType(.URL)
                Picker("Collection", selection: $selectedCollectionID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(collections) { collection in
                        Text(collection.name).tag(collection.id as UUID?)
                    }
                }
                Toggle("Favorite", isOn: $isFavorite)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Link")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
    }

    private func save() {
        do {
            let collection = collections.first(where: { $0.id == selectedCollectionID })
            _ = try BookmarkRepository(context: modelContext).save(
                url: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                collection: collection,
                favorite: isFavorite
            )
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
