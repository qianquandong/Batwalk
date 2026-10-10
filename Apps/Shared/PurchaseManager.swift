import Foundation
import Observation
import StoreKit

struct PurchaseOffer: Equatable { let displayPrice: String }
enum PurchaseOutcome { case purchased, pending, cancelled }

@MainActor
protocol PurchaseBackend {
    func loadOffer() async throws -> PurchaseOffer?
    func hasUnlock() async -> Bool
    func buy() async throws -> PurchaseOutcome
    func restore() async throws
}

@MainActor
private final class StoreKitBackend: PurchaseBackend {
    private var product: Product?
    func loadOffer() async throws -> PurchaseOffer? {
        product = try await Product.products(for: [SharedConfig.fullUnlockProductID]).first
        return product.map { PurchaseOffer(displayPrice: $0.displayPrice) }
    }
    func hasUnlock() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == SharedConfig.fullUnlockProductID,
               transaction.revocationDate == nil { return true }
        }
        return false
    }
    func buy() async throws -> PurchaseOutcome {
        guard let product else { throw PurchaseError.unavailable }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PurchaseError.unverified }
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw PurchaseError.unavailable
        }
    }
    func restore() async throws { try await AppStore.sync() }
}

private enum PurchaseError: LocalizedError {
    case unavailable, unverified
    var errorDescription: String? {
        switch self {
        case .unavailable: return "The purchase isn't available right now. Please try again."
        case .unverified: return "The App Store couldn't verify this purchase. Please restore or try again."
        }
    }
}

/// StoreKit owns the entitlement. Game saves and collection backups never grant it.
@MainActor
@Observable
final class PurchaseManager {
    private(set) var product: PurchaseOffer?
    private(set) var isUnlocked = false
    private(set) var hasCheckedEntitlements = false
    private(set) var isBusy = false
    private(set) var isLoadingProduct = false
    private(set) var message: String?
    var lastError: String?
    @ObservationIgnored private let backend: any PurchaseBackend
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(backend: (any PurchaseBackend)? = nil) { self.backend = backend ?? StoreKitBackend() }

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update,
                   transaction.productID == SharedConfig.fullUnlockProductID {
                    await transaction.finish()
                    await self.refreshEntitlements()
                    if self.isUnlocked { self.message = "Full unlock is active." }
                }
            }
        }
        Task { await refreshEntitlements(); await loadProduct() }
    }

    func loadProduct() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        lastError = nil
        do {
            product = try await backend.loadOffer()
            if product == nil { lastError = PurchaseError.unavailable.localizedDescription }
        } catch { lastError = error.localizedDescription }
    }

    func refreshEntitlements() async {
        isUnlocked = await backend.hasUnlock()
        hasCheckedEntitlements = true
    }

    func purchase() async {
        guard !isBusy else { return }
        guard product != nil else { lastError = PurchaseError.unavailable.localizedDescription; return }
        isBusy = true; lastError = nil; message = nil
        defer { isBusy = false }
        do {
            switch try await backend.buy() {
            case .purchased:
                await refreshEntitlements()
                message = isUnlocked ? "Full unlock is active." : "Purchase received. Please restore if it hasn't appeared yet."
            case .pending: message = "Waiting for App Store approval. Your walks can continue."
            case .cancelled: message = "Purchase cancelled."
            }
        } catch { lastError = error.localizedDescription }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true; lastError = nil; message = nil
        defer { isBusy = false }
        do {
            try await backend.restore()
            await refreshEntitlements()
            message = isUnlocked ? "Full unlock restored." : "No full unlock found for this Apple Account."
        } catch { lastError = error.localizedDescription }
    }
}
