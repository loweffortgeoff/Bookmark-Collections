import Foundation

enum ShareStorageDiagnostics {
    static func recoveryMessage(for _: Error) -> String {
        "Tucked could not open its shared library. Open Tucked, then try sharing again."
    }

    /// Error domains and codes only, following the underlying-error chain.
    /// Safe to log publicly: it carries no paths, URLs, or descriptions.
    /// A Swift error such as `SwiftDataError` bridges to an opaque domain and code,
    /// so the underlying POSIX or Cocoa error is what names the real cause.
    static func logSummary(for error: Error) -> String {
        var parts: [String] = []
        var current: NSError? = error as NSError
        while let nsError = current, parts.count < 4 {
            parts.append("\(nsError.domain) \(nsError.code)")
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return parts.joined(separator: " <- ")
    }
}
