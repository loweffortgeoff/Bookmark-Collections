import Observation

/// What a menu bar item or Home Screen Quick Action asks the library window to show.
enum MenuBarRequest: Equatable {
    case destination(LibraryDestination)
    case search
    case settings
    case addLink(prefilledURL: String?)
    case saveFromClipboard
    case newSnippet
}

/// Hands a menu bar or Quick Action choice to the library window. The window
/// may not exist yet (closed, or a cold launch), so the request stays pending
/// until the window consumes it.
@MainActor
@Observable
final class MenuBarRouter {
    /// One router for the app, so the scene delegate and the menu bar share it.
    static let shared = MenuBarRouter()

    private(set) var pending: MenuBarRequest?
    /// Bumps on every request so repeating the same choice still triggers `onChange`.
    private(set) var generation = 0

    func request(_ request: MenuBarRequest) {
        pending = request
        generation += 1
    }

    func take() -> MenuBarRequest? {
        defer { pending = nil }
        return pending
    }

    /// Always clears the pending request. Returns nil when `blocked`: a request
    /// that arrives over an unsaved draft, the paywall, or a drop summary is
    /// dropped, not kept (DECISIONS 2026-11-10), so it never fires later.
    func consume(blocked: Bool) -> MenuBarRequest? {
        let request = take()
        return blocked ? nil : request
    }
}
