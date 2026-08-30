import Foundation

enum BookmarkLimit {
    static let freeBookmarkLimit = 10

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
