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
        let monitor = SyncHealthMonitor {
            throw TestError.accountLookupFailed
        }

        await monitor.refresh()

        guard case let .error(message) = monitor.status else {
            return XCTFail("Expected an error status")
        }
        XCTAssertTrue(message.contains("Couldn’t check iCloud account"))
        XCTAssertTrue(message.contains("Account lookup failed"))
    }

    private func makeMonitor(returning status: CKAccountStatus) -> SyncHealthMonitor {
        SyncHealthMonitor { status }
    }
}

private enum TestError: LocalizedError {
    case accountLookupFailed

    var errorDescription: String? {
        "Account lookup failed"
    }
}
