import CloudKit
import Combine
import Foundation

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
final class SyncHealthMonitor: ObservableObject {
    typealias AccountStatusLoader = @Sendable () async throws -> CKAccountStatus

    @Published private(set) var status: SyncHealthStatus = .checking

    private let loadAccountStatus: AccountStatusLoader
    private var notificationTask: Task<Void, Never>?

    init(loadAccountStatus: @escaping AccountStatusLoader = SyncHealthMonitor.loadDefaultAccountStatus) {
        self.loadAccountStatus = loadAccountStatus
    }

    deinit {
        notificationTask?.cancel()
    }

    func start() {
        guard notificationTask == nil else { return }
        notificationTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
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

    nonisolated private static func loadDefaultAccountStatus() async throws -> CKAccountStatus {
        let process = ProcessInfo.processInfo
        guard !process.arguments.contains("-ui-testing"),
              process.environment["XCTestConfigurationFilePath"] == nil else {
            return .couldNotDetermine
        }
        return try await CKContainer.default().accountStatus()
    }
}
