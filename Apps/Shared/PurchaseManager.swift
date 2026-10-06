import Foundation
import Observation
import StoreKit

/// $1.99 one-time non-consumable unlock (PRD §2.10) with StoreKit 2.
/// Both apps read the entitlement directly from StoreKit, so a purchase on the
/// iPhone unlocks the Watch without any custom sync.
///
/// Never sell step skips, hatch odds, energy, or Friendship boosts.
@MainActor
@Observable
final class PurchaseManager {
    private(set) var product: Product?
    private(set) var isUnlocked = false
    /// False until the first entitlement check finishes — don't act on `isUnlocked` before that.
    private(set) var hasCheckedEntitlements = false
    private(set) var isBusy = false
    var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [SharedConfig.fullUnlockProductID]).first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == SharedConfig.fullUnlockProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
        hasCheckedEntitlements = true
    }

    func purchase() async {
        guard let product else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }
}
