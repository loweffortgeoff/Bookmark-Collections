import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Finds a copied web address for Add Link. URLs only: plain text and
/// snippets are never offered. Pattern detection runs before any read so
/// non-URL clipboard content never triggers a paste prompt.
enum ClipboardURLAssist {
    /// The clipboard text as a cleaned web address, or nil when it is not
    /// exactly one http(s) address (prose that merely contains a URL is nil).
    static func validWebURL(from raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let candidate = NormalizedURL.userEntered(trimmed)
        guard (try? NormalizedURL(candidate)) != nil else { return nil }
        return candidate
    }

    nonisolated static var defaultIsUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    #if os(macOS)
    /// Reads the clipboard only when it probably holds a web URL (macOS 15.4+).
    static func currentClipboardURL(isUITesting: Bool = defaultIsUITesting) async -> String? {
        guard !isUITesting else { return nil }
        guard #available(macOS 15.4, *) else { return nil }
        let pasteboard = NSPasteboard.general
        guard let patterns = try? await pasteboard.detectedPatterns(for: [\.probableWebURL]),
              patterns.contains(\NSPasteboard.DetectedValues.probableWebURL) else { return nil }
        return validWebURL(from: pasteboard.string(forType: .string))
    }
    #else
    /// True when the clipboard probably holds a web URL. Shows no paste banner.
    static func clipboardHasProbableWebURL(isUITesting: Bool = defaultIsUITesting) async -> Bool {
        guard !isUITesting, UIPasteboard.general.hasStrings else { return false }
        guard let patterns = try? await UIPasteboard.general.detectedPatterns(for: [\.probableWebURL]) else {
            return false
        }
        return patterns.contains(\UIPasteboard.DetectedValues.probableWebURL)
    }

    /// Direct read for the explicit "Save from Clipboard" Quick Action. The
    /// system paste prompt is accepted here because the person asked for it.
    static func readClipboardURLForExplicitAction(isUITesting: Bool = defaultIsUITesting) -> String? {
        guard !isUITesting else { return nil }
        return validWebURL(from: UIPasteboard.general.string)
    }
    #endif
}
