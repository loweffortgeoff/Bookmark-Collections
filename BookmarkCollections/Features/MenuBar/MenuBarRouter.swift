import Observation

/// What a menu bar item asks the library window to show.
enum MenuBarRequest: Equatable {
    case destination(LibraryDestination)
    case search
    case settings
}

/// Hands a menu bar choice to the library window. The window may not exist
/// yet (it was closed), so the request stays pending until the window consumes it.
@MainActor
@Observable
final class MenuBarRouter {
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
}
