import Observation
import StoreKit

@MainActor
@Observable
final class Storefront {
    static let lifetimeProductID = "com.loweffortapps.BookmarkCollections.lifetime"

    private(set) var product: Product?
    private(set) var isUnlocked = PurchaseAccess.isUnlocked
    private(set) var isLoading = false
    var errorMessage: String?

    private var transactionUpdates: Task<Void, Never>?

    init() {
        transactionUpdates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case let .verified(transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
        Task { [weak self] in
            await self?.load()
        }
    }

    func load() async {
        guard PaywallConfiguration.isEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.lifetimeProductID]).first
            await refreshEntitlement()
            if product == nil {
                errorMessage = "Tucked Pro is not available right now."
            }
        } catch {
            errorMessage = "Tucked Pro is not available right now."
        }
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await transaction.finish()
                await refreshEntitlement()
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
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isUnlocked {
                errorMessage = "No Tucked Pro purchase was found for this Apple Account."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.lifetimeProductID,
                  transaction.revocationDate == nil else {
                continue
            }
            unlocked = true
        }
        isUnlocked = unlocked
        PurchaseAccess.setUnlocked(unlocked)
    }
}
