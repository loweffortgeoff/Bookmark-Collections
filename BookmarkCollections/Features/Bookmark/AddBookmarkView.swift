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
    @FocusState private var isURLFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Web Address", text: $urlString, prompt: Text("https://example.com"))
                    .textContentType(.URL)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .focused($isURLFieldFocused)
                    .onSubmit { if canSave { save() } }
                CollectionPicker(collections: collections, selection: $selectedCollectionID)
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
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 240)
        // The sheet only ever opens empty, so the address field is the next step.
        .onAppear { isURLFieldFocused = true }
    }

    private var canSave: Bool {
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
