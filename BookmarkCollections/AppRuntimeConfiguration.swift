import Foundation

struct AppRuntimeConfiguration {
    let usesInMemoryStore: Bool
    let usesCloudKit: Bool
    let isUITesting: Bool
    let simulatesStoreOpenFailure: Bool
    let freeBookmarkLimitOverride: Int?

    init(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        isUITesting = arguments.contains("-ui-testing")
        usesInMemoryStore = environment["XCTestConfigurationFilePath"] != nil || isUITesting
        usesCloudKit = !usesInMemoryStore
        #if DEBUG
        simulatesStoreOpenFailure = isUITesting && arguments.contains("-simulate-store-open-failure")
        #else
        simulatesStoreOpenFailure = false
        #endif
        freeBookmarkLimitOverride = Self.parseFreeLimit(from: arguments)
    }

    /// Reads `-free-limit N`. Ignores a missing, non-numeric, or negative value.
    private static func parseFreeLimit(from arguments: [String]) -> Int? {
        guard let flag = arguments.firstIndex(of: "-free-limit") else { return nil }
        let valueIndex = arguments.index(after: flag)
        guard valueIndex < arguments.endIndex,
              let value = Int(arguments[valueIndex]),
              value >= 0
        else { return nil }
        return value
    }
}
