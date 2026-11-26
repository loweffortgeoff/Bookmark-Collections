import CloudKit
import XCTest
@testable import BookmarkCollections

@MainActor
final class SyncHealthMonitorTests: XCTestCase {
    func testRefreshMapsAvailableAccount() async {
        let monitor = makeMonitor(returning: .available)

        await monitor.refresh()

        XCTAssertEqual(monitor.status, .available)
        XCTAssertEqual(monitor.status.title, "iCloud account available")
    }

    func testRefreshMapsUnavailableAccountStates() async {
        let cases: [(CKAccountStatus, SyncHealthStatus)] = [
            (.noAccount, .noAccount),
            (.restricted, .restricted),
            (.temporarilyUnavailable, .temporarilyUnavailable),
            (.couldNotDetermine, .temporarilyUnavailable)
        ]

        for (accountStatus, expectedStatus) in cases {
            let monitor = makeMonitor(returning: accountStatus)

            await monitor.refresh()

            XCTAssertEqual(monitor.status, expectedStatus)
        }
    }

    func testRefreshSurfacesLoaderFailureWithoutClaimingSyncSuccess() async {
        let monitor = SyncHealthMonitor(observesCloudKitEvents: false) {
            throw TestError.accountLookupFailed
        }

        await monitor.refresh()

        guard case let .error(message) = monitor.status else {
            return XCTFail("Expected an error status")
        }
        XCTAssertTrue(message.contains("Couldn’t check iCloud account"))
        XCTAssertTrue(message.contains("Account lookup failed"))
    }

    func testSuccessfulExportEventRecordsAndPersistsLastPushDate() {
        let defaults = makeDefaults()
        let monitor = SyncHealthMonitor(userDefaults: defaults, observesCloudKitEvents: false) { .available }
        let t1 = Date(timeIntervalSince1970: 1_800_000_000)

        monitor.recordSyncEvent(.init(kind: .export, endDate: t1, succeeded: true))

        XCTAssertEqual(monitor.lastPushDate, t1)
        XCTAssertNil(monitor.lastPullDate)
        let restored = SyncHealthMonitor(userDefaults: defaults, observesCloudKitEvents: false) { .available }
        XCTAssertEqual(restored.lastPushDate, t1)
    }

    func testSuccessfulImportEventRecordsAndPersistsLastPullDate() {
        let defaults = makeDefaults()
        let monitor = SyncHealthMonitor(userDefaults: defaults, observesCloudKitEvents: false) { .available }
        let t1 = Date(timeIntervalSince1970: 1_800_000_000)

        monitor.recordSyncEvent(.init(kind: .import, endDate: t1, succeeded: true))

        XCTAssertEqual(monitor.lastPullDate, t1)
        XCTAssertNil(monitor.lastPushDate)
        let restored = SyncHealthMonitor(userDefaults: defaults, observesCloudKitEvents: false) { .available }
        XCTAssertEqual(restored.lastPullDate, t1)
    }

    func testInProgressFailedAndSetupEventsDoNotAdvanceTimestamps() {
        let monitor = SyncHealthMonitor(userDefaults: makeDefaults(), observesCloudKitEvents: false) { .available }
        let t1 = Date(timeIntervalSince1970: 1_800_000_000)

        monitor.recordSyncEvent(.init(kind: .export, endDate: nil, succeeded: true))
        monitor.recordSyncEvent(.init(kind: .import, endDate: nil, succeeded: false))
        monitor.recordSyncEvent(.init(kind: .export, endDate: t1, succeeded: false))
        monitor.recordSyncEvent(.init(kind: .import, endDate: t1, succeeded: false))
        monitor.recordSyncEvent(.init(kind: .setup, endDate: t1, succeeded: true))

        XCTAssertNil(monitor.lastPushDate)
        XCTAssertNil(monitor.lastPullDate)
    }

    func testOlderEventDoesNotOverwriteNewerTimestamp() {
        let monitor = SyncHealthMonitor(userDefaults: makeDefaults(), observesCloudKitEvents: false) { .available }
        let t1 = Date(timeIntervalSince1970: 1_800_000_000)
        let t2 = t1.addingTimeInterval(60)

        monitor.recordSyncEvent(.init(kind: .export, endDate: t2, succeeded: true))
        monitor.recordSyncEvent(.init(kind: .export, endDate: t1, succeeded: true))
        monitor.recordSyncEvent(.init(kind: .import, endDate: t2, succeeded: true))
        monitor.recordSyncEvent(.init(kind: .import, endDate: t1, succeeded: true))

        XCTAssertEqual(monitor.lastPushDate, t2)
        XCTAssertEqual(monitor.lastPullDate, t2)
    }

    func testFormattedTimestampShowsHonestPlaceholderWhenUnobserved() {
        XCTAssertEqual(SyncHealthMonitor.formattedTimestamp(nil), "Not yet observed")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNotEqual(SyncHealthMonitor.formattedTimestamp(now.addingTimeInterval(-120), relativeTo: now), "Not yet observed")
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "SyncHealthMonitorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func makeMonitor(returning status: CKAccountStatus) -> SyncHealthMonitor {
        SyncHealthMonitor(observesCloudKitEvents: false) { status }
    }
}

private enum TestError: LocalizedError {
    case accountLookupFailed

    var errorDescription: String? {
        "Account lookup failed"
    }
}
