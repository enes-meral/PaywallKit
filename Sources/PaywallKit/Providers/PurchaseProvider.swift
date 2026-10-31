import Foundation

/// Abstraction over the store backend.
///
/// PaywallKit ships with `StoreKitPurchaseProvider` (StoreKit 2). To use RevenueCat, Adapty,
/// your own server, etc., create a type that conforms to this protocol and pass it to
/// `PaywallView`. PaywallKit never talks to the store directly.
public protocol PurchaseProvider: Sendable {
    /// Loads the products for the given identifiers. Implementations should only attach an
    /// `introductoryOffer` when the current user is actually eligible for it.
    func loadProducts(ids: [String]) async throws -> [PaywallProduct]

    /// Purchases the product. Implementations are responsible for verifying and finishing
    /// the transaction before returning `.success`.
    func purchase(_ product: PaywallProduct) async throws -> PurchaseResult

    /// Restores previous purchases (App Review requires a visible "Restore" action).
    func restorePurchases() async throws -> RestoreResult
}

public enum PurchaseResult: Hashable, Sendable {
    case success(productID: String)
    /// The purchase needs approval (e.g. Ask to Buy) and will complete later.
    case pending
    case userCancelled
}

public enum RestoreResult: Hashable, Sendable {
    case restored(productIDs: Set<String>)
    case nothingToRestore
}

public enum PaywallError: Error, Hashable, Sendable {
    case productNotFound(id: String)
    case failedVerification
    case noProductsAvailable
}
