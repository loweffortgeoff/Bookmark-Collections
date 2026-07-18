import SwiftData
import SwiftUI

struct CollectionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let collection: BookmarkCollection?
    @State private var name: String
    @State private var errorMessage: String?

    init(collection: BookmarkCollection? = nil) {
        self.collection = collection
        _name = State(initialValue: collection?.name ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(collection == nil ? "New Collection" : "Rename Collection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 340, minHeight: 180)
    }

    private func save() {
        do {
            let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let repository = CollectionRepository(context: modelContext)
            if let collection {
                try repository.rename(collection, to: value)
            } else {
                _ = try repository.create(name: value)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
