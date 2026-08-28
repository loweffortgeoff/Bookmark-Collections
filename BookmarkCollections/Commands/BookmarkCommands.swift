import SwiftUI

@MainActor
struct BookmarkCommandActions {
    let addLink: () -> Void
    let focusSearch: () -> Void
    let newCollection: () -> Void
    let newSnippet: () -> Void
    let selectedBookmark: Bookmark?
    let canDeleteSelected: Bool
    let openSelected: () -> Void
    let shareSelected: () -> Void
    let deleteSelected: () -> Void
    let surpriseMe: () -> Void
    let canSurpriseMe: Bool
}

private struct BookmarkCommandActionsKey: FocusedValueKey {
    typealias Value = BookmarkCommandActions
}

extension FocusedValues {
    var bookmarkCommandActions: BookmarkCommandActions? {
        get { self[BookmarkCommandActionsKey.self] }
        set { self[BookmarkCommandActionsKey.self] = newValue }
    }
}

struct BookmarkCommands: Commands {
    @FocusedValue(\.bookmarkCommandActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Link") { actions?.addLink() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
            Button("New Snippet") { actions?.newSnippet() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions == nil)
            Button("New Collection") { actions?.newCollection() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandGroup(after: .textEditing) {
            Button("Find") { actions?.focusSearch() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)
        }

        CommandMenu("Bookmark") {
            Button("Open") { actions?.openSelected() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions?.selectedBookmark == nil)
            Button("Share") { actions?.shareSelected() }
                .disabled(actions?.selectedBookmark == nil)
            Button("Surprise Me") { actions?.surpriseMe() }
                .disabled(actions?.canSurpriseMe != true)
            Divider()
            Button("Move to Recently Deleted") { actions?.deleteSelected() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(actions?.canDeleteSelected != true)
        }
    }
}
