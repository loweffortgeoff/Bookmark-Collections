#if os(macOS)
import AppKit
import SwiftUI

/// Menu bar helper: jump into the library window at a view, search, open
/// Settings, or quit. Every item except Quit opens (or raises) the window.
struct MenuBarContent: View {
    let router: MenuBarRouter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Search", systemImage: "magnifyingglass") { show(.search) }
        Divider()
        Button("Links", systemImage: LibraryDestination.links.systemImage) { show(.destination(.links)) }
        Button("Images", systemImage: LibraryDestination.images.systemImage) { show(.destination(.images)) }
        Button("Snippets", systemImage: LibraryDestination.snippets.systemImage) { show(.destination(.snippets)) }
        Divider()
        Button("Open Tucked") { show(nil) }
        Button("Settings…") { show(.settings) }
        Divider()
        Button("Quit Tucked") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ request: MenuBarRequest?) {
        if let request { router.request(request) }
        openWindow(id: LibraryWindow.id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

enum LibraryWindow {
    static let id = "library"
}
#endif
