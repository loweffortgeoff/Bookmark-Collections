import SwiftUI

struct LibraryToolbar: ToolbarContent {
    @Binding var sort: BookmarkSort
    @Binding var ascending: Bool
    let onAdd: () -> Void
    let onNewSnippet: () -> Void
    let onAddImages: () -> Void
    let onNewCollection: () -> Void
    let onSettings: () -> Void
    let showEmptyRecentlyDeleted: Bool
    let onEmptyRecentlyDeleted: () -> Void
    let showSurpriseMe: Bool
    let canSurpriseMe: Bool
    let onSurpriseMe: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if showEmptyRecentlyDeleted {
                Button(role: .destructive, action: onEmptyRecentlyDeleted) {
                    Label("Empty Recently Deleted", systemImage: "trash.slash")
                }
            }

            if showSurpriseMe {
                Button(action: onSurpriseMe) {
                    Label("Surprise me", systemImage: "shuffle")
                }
                .disabled(!canSurpriseMe)
                .accessibilityIdentifier("library.surpriseMe")
            }

            Menu {
                Picker("Sort By", selection: $sort) {
                    Text("Date Added").tag(BookmarkSort.dateAdded)
                    Text("Date Modified").tag(BookmarkSort.dateModified)
                    Text("Title").tag(BookmarkSort.title)
                    Text("Domain").tag(BookmarkSort.domain)
                }
                Toggle("Ascending", isOn: $ascending)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Menu {
                Button("Add Link", systemImage: "link", action: onAdd)
                Button("New Snippet", systemImage: "text.quote", action: onNewSnippet)
                #if os(macOS)
                Button("Add Images…", systemImage: "photo.badge.plus", action: onAddImages)
                #endif
                Button("New Collection", systemImage: "folder.badge.plus", action: onNewCollection)
                Divider()
                Button("Settings", systemImage: "gear", action: onSettings)
            } label: {
                Label("Add", systemImage: "plus")
            }
            .accessibilityIdentifier("library.addMenu")
        }
    }
}
