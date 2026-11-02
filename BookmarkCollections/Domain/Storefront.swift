import Observation
import StoreKit

@MainActor
@Observable
final class Storefront {
    static let lifetimeProductID = "com.loweffortapps.BookmarkCollections.tuckedforlife"

    private(set) var product: Product?
    private(set) var isUnlocked = PurchaseAccess.isUnlocked
    private(set) var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var transactionUpdates: Task<Void, Never>?
    private var entitlementRevision = 0

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        // UI tests use a disposable library. Outside the local StoreKit audit,
        // a real purchase on the test machine would unlock it and hide the paywall.
        guard !arguments.contains("-ui-testing") || arguments.contains("-storekit-audit") else { return }
        transactionUpdates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                self?.apply(transaction)
                await transaction.finish()
            }
        }
        Task { [weak self] in
            await self?.load()
        }
    }

    deinit {
        transactionUpdates?.cancel()
    }

    func load() async {
        guard PaywallConfiguration.isEnabled else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        // Ownership must not depend on the availability of the product catalog.
        await refreshEntitlement()
        do {
            product = try await Product.products(for: [Self.lifetimeProductID]).first
            // An empty answer means the product is not on sale, so lift the cap.
            // A thrown error (offline, App Store unreachable) keeps the last answer.
            PurchaseAccess.setProductAvailable(product != nil)
            if product == nil && !isUnlocked {
                errorMessage = "Tucked for Life is not available right now."
            }
        } catch {
            if !isUnlocked {
                errorMessage = "Tucked for Life is not available right now."
            }
        }
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                // Deliver access before finishing. On Mac, currentEntitlements
                // can still be empty when the verified purchase returns.
                apply(transaction)
                await transaction.finish()
            case let .success(.unverified(_, error)):
                errorMessage = error.localizedDescription
            case .pending:
                errorMessage = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isUnlocked {
                errorMessage = "No Tucked for Life purchase was found for this Apple Account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        entitlementRevision += 1
        let revision = entitlementRevision
        let result = await Transaction.latest(for: Self.lifetimeProductID)
        // A purchase/update received during this lookup is newer than its result.
        guard revision == entitlementRevision else { return }
        if case let .verified(transaction) = result {
            apply(transaction)
        } else {
            setUnlocked(false)
        }
    }

    private func apply(_ transaction: Transaction) {
        guard transaction.productID == Self.lifetimeProductID,
              transaction.productType == .nonConsumable else { return }
        entitlementRevision += 1
        setUnlocked(transaction.revocationDate == nil)
    }

    private func setUnlocked(_ unlocked: Bool) {
        isUnlocked = unlocked
        PurchaseAccess.setUnlocked(unlocked)
        if unlocked { errorMessage = nil }
    }
}
