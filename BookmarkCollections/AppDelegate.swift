import OSLog

private let remoteNotificationLog = Logger(subsystem: "com.loweffortapps.BookmarkCollections", category: "RemoteNotifications")

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        remoteNotificationLog.notice("Registered for remote notifications, token length \(deviceToken.count)")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        remoteNotificationLog.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        remoteNotificationLog.notice("Received remote notification")
        completionHandler(.newData)
    }

    /// SwiftUI apps never receive `application(_:performActionFor:)`, so Home
    /// Screen Quick Actions arrive through this scene delegate instead. The
    /// shortcut is not read here; doing so as well would fire it twice.
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

/// Routes Home Screen Quick Actions into `MenuBarRouter.shared`. The library
/// consumes the request when it appears (cold launch) or when it changes
/// (warm resume).
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Cold launch: the shortcut arrives with the connection options.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let item = connectionOptions.shortcutItem,
              let action = HomeScreenQuickAction(rawValue: item.type) else { return }
        MainActor.assumeIsolated {
            MenuBarRouter.shared.request(action.routerRequest)
        }
    }

    /// Warm resume: the app was already running.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = HomeScreenQuickAction(rawValue: shortcutItem.type) else {
            completionHandler(false)
            return
        }
        MainActor.assumeIsolated {
            MenuBarRouter.shared.request(action.routerRequest)
        }
        completionHandler(true)
    }
}
#elseif os(macOS)
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.registerForRemoteNotifications()
    }

    /// Closing the library window leaves Tucked running in the menu bar. The
    /// menu bar's Open Tucked reopens the window and Quit quits, so there is
    /// always a visible way back (App Review guideline 4).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        remoteNotificationLog.notice("Registered for remote notifications, token length \(deviceToken.count)")
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        remoteNotificationLog.error("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    func application(
        _ application: NSApplication,
        didReceiveRemoteNotification userInfo: [String: Any]
    ) {
        remoteNotificationLog.notice("Received remote notification")
    }
}
#endif
