import Foundation

enum BookmarkLimit {
    static let defaultFreeBookmarkLimit = 10

    /// Set from the `-free-limit N` launch argument so the paywall can be reached without
    /// saving eleven bookmarks by hand. Nil in every normal launch.
    ///
    /// `nonisolated(unsafe)` because this is written once in `BookmarkCollectionsApp.init` before any
    /// concurrent work starts, and only read afterwards. Making it `@MainActor` would push
    /// isolation onto `canCreate` and every caller, including the share extension.
    nonisolated(unsafe) static var freeBookmarkLimitOverride: Int?

    static var freeBookmarkLimit: Int {
        freeBookmarkLimitOverride ?? defaultFreeBookmarkLimit
    }

    static func canCreate(activeBookmarkCount: Int, isUnlocked: Bool) -> Bool {
        isUnlocked || activeBookmarkCount < freeBookmarkLimit
    }
}

enum PaywallConfiguration {
    static var isEnabled: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "PaywallEnabled") else {
            return true
        }
        if let value = value as? Bool { return value }
        return (value as? String) != "NO"
    }
}

enum PurchaseAccess {
    private static let entitlementKey = "tuckedProUnlocked"
    private static let appGroupIdentifier = "group.com.loweffortapps.BookmarkCollections"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var isUnlocked: Bool {
        defaults.bool(forKey: entitlementKey)
    }

    static func setUnlocked(_ isUnlocked: Bool) {
        defaults.set(isUnlocked, forKey: entitlementKey)
    }
}
