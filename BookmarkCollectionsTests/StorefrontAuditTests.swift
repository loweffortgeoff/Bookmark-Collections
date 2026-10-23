import StoreKit
import StoreKitTest
import XCTest
@testable import BookmarkCollections

/// These tests use Xcode's local StoreKit server, never a real purchase.
@MainActor
final class StorefrontAuditTests: XCTestCase {
    private func session() async throws -> SKTestSession {
        try XCTSkipUnless(ProcessInfo.processInfo.arguments.contains("-storekit-audit"), "Run StorefrontAuditTests with the Tucked Audit scheme.")
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Audit", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        // Resetting the server does not synchronously invalidate the client's
        // transaction history. Start each scenario only after it is empty.
        for _ in 0..<100 {
            if await Transaction.latest(for: BookmarkCollections.Storefront.lifetimeProductID) == nil { return session }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("Local StoreKit history did not clear before the scenario.")
        return session
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("StoreKit state did not converge within five seconds", file: file, line: line)
    }

    private func loadedStore() async throws -> BookmarkCollections.Storefront {
        let storefront = BookmarkCollections.Storefront()
        try await waitUntil { storefront.product != nil && !storefront.isLoading }
        return storefront
    }

    func testProductLoadsAndFreshAccountStaysLocked() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        XCTAssertEqual(storefront.product?.id, BookmarkCollections.Storefront.lifetimeProductID)
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertFalse(PurchaseAccess.isUnlocked)
    }

    func testLocalStoreKitTransactionIsVerifiedByTheAppProcess() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let transaction = try await session.buyProduct(identifier: BookmarkCollections.Storefront.lifetimeProductID)
        print("AUDIT local transactions: \(session.allTransactions().count); environment: \(transaction.environment)")
        var verified = false
        for _ in 0..<100 {
            for await result in Transaction.currentEntitlements {
                switch result {
                case let .verified(value):
                    print("AUDIT verified environment: \(value.environment)")
                    verified = value.productID == BookmarkCollections.Storefront.lifetimeProductID
                case let .unverified(_, error):
                    print("AUDIT verification failed: \(error)")
                }
            }
            if verified { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(verified, "The local StoreKit harness must deliver a verified entitlement before app lifecycle results are trusted.")
    }

    func testPurchaseUnlocksSharedAccessAndNewStorefront() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        await storefront.purchase()
        print("AUDIT purchase result: unlocked=\(storefront.isUnlocked), shared=\(PurchaseAccess.isUnlocked), error=\(String(describing: storefront.errorMessage)), localTransactions=\(session.allTransactions().count)")
        if let latest = await Transaction.latest(for: BookmarkCollections.Storefront.lifetimeProductID) {
            switch latest {
            case let .verified(transaction): print("AUDIT latest transaction verified; environment=\(transaction.environment), type=\(transaction.productType)")
            case let .unverified(_, error): print("AUDIT latest transaction unverified: \(error)")
            }
        }
        try await waitUntil { storefront.isUnlocked }
        XCTAssertTrue(storefront.isUnlocked)
        XCTAssertTrue(PurchaseAccess.isUnlocked)
        let relaunched = try await loadedStore()
        print("AUDIT after new storefront: original=\(storefront.isUnlocked), new=\(relaunched.isUnlocked), shared=\(PurchaseAccess.isUnlocked)")
        XCTAssertTrue(relaunched.isUnlocked)
    }

    func testCancelledPurchaseStaysLocked() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await storefront.purchase()
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertFalse(PurchaseAccess.isUnlocked)
    }

    func testFailedPurchaseStaysLockedAndShowsError() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await storefront.purchase()
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertNotNil(storefront.errorMessage)
    }

    func testPendingPurchaseUnlocksOnlyAfterApproval() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        session.askToBuyEnabled = true
        let storefront = try await loadedStore()
        await storefront.purchase()
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertEqual(storefront.errorMessage, "Your purchase is waiting for approval.")
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await waitUntil { storefront.isUnlocked && PurchaseAccess.isUnlocked }
        XCTAssertNil(storefront.errorMessage, "Approval must clear the pending purchase message.")
    }

    func testRefundRevokesSharedAccessWithoutRestart() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        await storefront.purchase()
        try await waitUntil { storefront.isUnlocked }
        XCTAssertTrue(storefront.isUnlocked)
        // The local Mac StoreKit server can report purchase success before
        // its entitlement projection exists. Settle that simulation before
        // asking it to generate a refund/update for the purchase.
        var purchaseVisible = false
        for _ in 0..<100 {
            for await result in Transaction.currentEntitlements {
                if case let .verified(value) = result,
                   value.productID == BookmarkCollections.Storefront.lifetimeProductID {
                    purchaseVisible = true
                }
            }
            if purchaseVisible { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(purchaseVisible, "Control: local purchase must be projected before simulating its refund.")
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await waitUntil { !storefront.isUnlocked && !PurchaseAccess.isUnlocked }
        // latest(for:) includes revoked history. A fresh launch must not grant
        // access just because that history still contains the purchase.
        PurchaseAccess.setUnlocked(true)
        let relaunched = try await loadedStore()
        XCTAssertFalse(relaunched.isUnlocked)
        XCTAssertFalse(PurchaseAccess.isUnlocked)
    }

    func testRestoreFindsExistingPurchase() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        _ = try await session.buyProduct(identifier: BookmarkCollections.Storefront.lifetimeProductID)
        PurchaseAccess.setUnlocked(false)
        let storefront = try await loadedStore()
        await storefront.restorePurchases()
        XCTAssertTrue(storefront.isUnlocked)
        XCTAssertTrue(PurchaseAccess.isUnlocked)
    }

    func testRestoreWithoutPurchaseExplainsLockedState() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        await storefront.restorePurchases()
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertEqual(storefront.errorMessage, "No Tucked for Life purchase was found for this Apple Account.")
    }

    func testProductLoadFailureKeepsExistingVerifiedPurchaseAccessible() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        _ = try await session.buyProduct(identifier: BookmarkCollections.Storefront.lifetimeProductID)
        var verifiedOwner = false
        for _ in 0..<100 {
            if case .verified = await Transaction.latest(for: BookmarkCollections.Storefront.lifetimeProductID) {
                verifiedOwner = true
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(verifiedOwner, "Control: local StoreKit must expose a verified owner before simulating a catalog failure.")
        PurchaseAccess.setUnlocked(false)
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .loadProducts)
        let storefront = BookmarkCollections.Storefront()
        try await waitUntil { storefront.isUnlocked && !storefront.isLoading }
        XCTAssertTrue(storefront.isUnlocked, "A verified owner must retain access when the product catalog fails.")
        XCTAssertTrue(PurchaseAccess.isUnlocked)
    }

    func testSuccessfulPurchaseClearsEarlierRestoreError() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        await storefront.restorePurchases()
        XCTAssertNotNil(storefront.errorMessage)
        await storefront.purchase()
        try await waitUntil { storefront.isUnlocked }
        XCTAssertNil(storefront.errorMessage, "A successful purchase must not continue to show that no purchase was found.")
    }
    func testSuccessfulRestoreClearsEarlierError() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        let storefront = try await loadedStore()
        _ = try await session.buyProduct(identifier: BookmarkCollections.Storefront.lifetimeProductID)
        storefront.errorMessage = "Previous operation failed"
        await storefront.restorePurchases()
        XCTAssertTrue(storefront.isUnlocked)
        XCTAssertTrue(PurchaseAccess.isUnlocked)
        XCTAssertNil(storefront.errorMessage)
    }

    func testCatalogFailureWithoutPurchaseStaysLocked() async throws {
        let session = try await session()
        let old = PurchaseAccess.isUnlocked
        defer { session.clearTransactions(); PurchaseAccess.setUnlocked(old) }
        PurchaseAccess.setUnlocked(true)
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .loadProducts)
        let storefront = BookmarkCollections.Storefront()
        try await waitUntil { storefront.errorMessage != nil && !storefront.isLoading }
        XCTAssertFalse(storefront.isUnlocked)
        XCTAssertFalse(PurchaseAccess.isUnlocked)
        XCTAssertNil(storefront.product)
    }

}
