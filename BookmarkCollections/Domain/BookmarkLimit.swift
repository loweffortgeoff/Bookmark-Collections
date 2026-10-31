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

    /// Whether saving is actually capped right now. The cap only applies once the
    /// App Store has returned the Tucked for Life product, so nobody hits a paywall
    /// they cannot pay through (1.0.1: the product was attached to a different
    /// review and was not on sale when iOS 1.0 went live). Bookmarks saved past ten
    /// while the product was unavailable are kept; only new saves are blocked
    /// once it loads.
    static var isEnforced: Bool {
        isEnabled && PurchaseAccess.isProductAvailable
    }
}

enum PurchaseAccess {
    private static let entitlementKey = "tuckedProUnlocked"
    private static let productAvailableKey = "tuckedForLifeProductAvailable"
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

    /// Last answer from the App Store about whether Tucked for Life can be bought.
    /// Written by the app's Storefront and read through the app group by the share
    /// extension, which never loads StoreKit products itself. False until the app
    /// has seen the product at least once.
    static var isProductAvailable: Bool {
        defaults.bool(forKey: productAvailableKey)
    }

    static func setProductAvailable(_ isAvailable: Bool) {
        defaults.set(isAvailable, forKey: productAvailableKey)
    }
}
