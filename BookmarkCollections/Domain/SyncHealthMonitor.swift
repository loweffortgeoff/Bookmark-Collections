import CloudKit
import CoreData
import Foundation
import Observation
import OSLog

private let syncLogger = Logger(
    subsystem: "com.loweffortapps.BookmarkCollections",
    category: "CloudKitSync"
)

enum SyncHealthStatus: Equatable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case error(String)

    var title: String {
        switch self {
        case .checking: "Checking iCloud account…"
        case .available: "iCloud account available"
        case .noAccount: "No iCloud account"
        case .restricted: "iCloud access restricted"
        case .temporarilyUnavailable: "iCloud temporarily unavailable"
        case let .error(message): message
        }
    }

    var systemImage: String {
        switch self {
        case .checking: "arrow.trianglehead.2.clockwise"
        case .available: "checkmark.icloud"
        case .noAccount: "person.crop.circle.badge.exclamationmark"
        case .restricted: "lock.icloud"
        case .temporarilyUnavailable, .error: "exclamationmark.icloud"
        }
    }
}

@MainActor
@Observable
final class SyncHealthMonitor {
    typealias AccountStatusLoader = @Sendable () async throws -> CKAccountStatus

    enum SyncEventKind: Equatable, Sendable {
        case export
        case `import`
        case setup
    }

    struct SyncEventSnapshot: Equatable, Sendable {
        let kind: SyncEventKind
        let endDate: Date?
        let succeeded: Bool
    }

    static let lastPushDateKey = "tucked.sync.lastPushDate"
    static let lastPullDateKey = "tucked.sync.lastPullDate"

    private(set) var status: SyncHealthStatus = .checking
    private(set) var lastPushDate: Date?
    private(set) var lastPullDate: Date?

    @ObservationIgnored private let loadAccountStatus: AccountStatusLoader
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let notificationCenter: NotificationCenter
    @ObservationIgnored private let observesCloudKitEvents: Bool
    // Removed in deinit, which is nonisolated. NotificationCenter removal is thread-safe.
    @ObservationIgnored nonisolated(unsafe) private var eventObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var accountObserver: NSObjectProtocol?
    @ObservationIgnored private var isStarted = false

    init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        observesCloudKitEvents: Bool = SyncHealthMonitor.defaultObservesCloudKitEvents,
        loadAccountStatus: @escaping AccountStatusLoader = SyncHealthMonitor.loadDefaultAccountStatus
    ) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.observesCloudKitEvents = observesCloudKitEvents
        self.loadAccountStatus = loadAccountStatus
        lastPushDate = userDefaults.object(forKey: Self.lastPushDateKey) as? Date
        lastPullDate = userDefaults.object(forKey: Self.lastPullDateKey) as? Date
    }

    deinit {
        if let eventObserver { notificationCenter.removeObserver(eventObserver) }
        if let accountObserver { notificationCenter.removeObserver(accountObserver) }
    }

    /// Registers observers synchronously. Call before the `ModelContainer`
    /// opens so launch-time CloudKit mirroring events are not missed.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        if observesCloudKitEvents {
            eventObserver = notificationCenter.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let snapshot = Self.snapshot(from: notification) else { return }
                Task { @MainActor [weak self] in
                    self?.recordSyncEvent(snapshot)
                }
            }
        }
        accountObserver = notificationCenter.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func recordSyncEvent(_ event: SyncEventSnapshot) {
        guard event.succeeded, let endDate = event.endDate else { return }
        switch event.kind {
        case .export:
            guard lastPushDate.map({ endDate > $0 }) ?? true else { return }
            lastPushDate = endDate
            userDefaults.set(endDate, forKey: Self.lastPushDateKey)
            syncLogger.info("Observed iCloud push completed at \(endDate, privacy: .public)")
        case .import:
            guard lastPullDate.map({ endDate > $0 }) ?? true else { return }
            lastPullDate = endDate
            userDefaults.set(endDate, forKey: Self.lastPullDateKey)
            syncLogger.info("Observed iCloud pull completed at \(endDate, privacy: .public)")
        case .setup:
            return
        }
    }

    static func formattedTimestamp(_ date: Date?, relativeTo now: Date = Date()) -> String {
        guard let date else { return String(localized: "Not yet observed") }
        if now.timeIntervalSince(date) < 60 * 60 * 24 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: now)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    func refresh() async {
        do {
            switch try await loadAccountStatus() {
            case .available:
                status = .available
            case .noAccount:
                status = .noAccount
            case .restricted:
                status = .restricted
            case .temporarilyUnavailable, .couldNotDetermine:
                status = .temporarilyUnavailable
            @unknown default:
                status = .error("iCloud account status is unknown")
            }
        } catch {
            status = .error("Couldn’t check iCloud account: \(error.localizedDescription)")
        }
    }

    nonisolated static var defaultObservesCloudKitEvents: Bool {
        let process = ProcessInfo.processInfo
        return !process.arguments.contains("-ui-testing")
            && process.environment["XCTestConfigurationFilePath"] == nil
    }

    nonisolated private static func snapshot(from notification: Notification) -> SyncEventSnapshot? {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event else { return nil }
        let kind: SyncEventKind
        switch event.type {
        case .export: kind = .export
        case .import: kind = .import
        case .setup: kind = .setup
        @unknown default: return nil
        }
        syncLogger.debug("CloudKit event \(String(describing: event.type.rawValue), privacy: .public) ended: \(event.endDate != nil, privacy: .public) succeeded: \(event.succeeded, privacy: .public)")
        return SyncEventSnapshot(kind: kind, endDate: event.endDate, succeeded: event.succeeded)
    }

    nonisolated private static func loadDefaultAccountStatus() async throws -> CKAccountStatus {
        let process = ProcessInfo.processInfo
        guard !process.arguments.contains("-ui-testing"),
              process.environment["XCTestConfigurationFilePath"] == nil else {
            return .couldNotDetermine
        }
        return try await CKContainer.default().accountStatus()
    }
}
