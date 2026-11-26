/// The static Home Screen Quick Actions declared in Info.plist
/// (`UIApplicationShortcutItems`). Each routes through `MenuBarRouter`.
enum HomeScreenQuickAction: String, CaseIterable, Equatable, Sendable {
    case addLink = "com.loweffortapps.BookmarkCollections.quickaction.addLink"
    case saveFromClipboard = "com.loweffortapps.BookmarkCollections.quickaction.saveFromClipboard"
    case newSnippet = "com.loweffortapps.BookmarkCollections.quickaction.newSnippet"
    case search = "com.loweffortapps.BookmarkCollections.quickaction.search"

    var routerRequest: MenuBarRequest {
        switch self {
        case .addLink: .addLink(prefilledURL: nil)
        case .saveFromClipboard: .saveFromClipboard
        case .newSnippet: .newSnippet
        case .search: .search
        }
    }
}
