import SwiftData
import SwiftUI

struct AddBookmarkView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \BookmarkCollection.sortPosition) private var collections: [BookmarkCollection]

    /// Shows the existing bookmark in the library. Nil hides the View button.
    private let onViewExisting: ((PersistentIdentifier) -> Void)?

    // The paywall opens over the form, so the typed address is still here
    // when it closes.
    @State private var showsPaywall = false
    @State private var urlString: String
    @State private var selectedCollectionID: UUID?
    @State private var isFavorite = false
    @State private var errorMessage: String?
    @State private var existingMatch: ExistingLinkMatch?
    @FocusState private var isURLFieldFocused: Bool

    init(initialURL: String = "", onViewExisting: ((PersistentIdentifier) -> Void)? = nil) {
        _urlString = State(initialValue: initialURL)
        self.onViewExisting = onViewExisting
    }

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
                if let existingMatch {
                    existingMatchRow(existingMatch)
                }
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
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 240)
        #endif
        // The address field is the next step, whether empty or pre-filled.
        .onAppear { isURLFieldFocused = true }
        .onChange(of: urlString, initial: true) {
            existingMatch = try? BookmarkRepository(context: modelContext)
                .existingLinkMatch(for: urlString, applyUserEnteredFixup: true)
        }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    }

    private func existingMatchRow(_ match: ExistingLinkMatch) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Label(match.noticeText(), systemImage: "bookmark.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("addBookmark.existingMatchNotice")
            if case .active = match.status, let onViewExisting {
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button("View") {
                    dismiss()
                    onViewExisting(match.bookmarkPersistentID)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("addBookmark.viewExisting")
            }
        }
    }

    private var canSave: Bool {
        !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            let collection = collections.first(where: { $0.id == selectedCollectionID })
            _ = try BookmarkRepository(context: modelContext).save(
                url: NormalizedURL.userEntered(urlString),
                collection: collection,
                favorite: isFavorite
            )
            dismiss()
        } catch {
            if error as? BookmarkRepository.LimitError == .limitReached {
                showsPaywall = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
