#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The one place snippet text reaches the pasteboard, shared by the bookmark
/// context menu and the macOS Bookmark menu.
enum SnippetPasteboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
