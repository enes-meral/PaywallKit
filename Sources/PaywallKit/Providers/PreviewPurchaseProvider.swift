import Foundation

/// A fake `PurchaseProvider` for SwiftUI previews, demos and tests.
/// It never contacts the App Store.
public final class PreviewPurchaseProvider: PurchaseProvider {
    public let products: [PaywallProduct]
    public let purchaseResult: PurchaseResult?
    public let restoreResult: RestoreResult
    public let delay: Duration
    public let failsToLoad: Bool

    /// - Parameters:
    ///   - purchaseResult: What `purchase(_:)` returns. `nil` means "success with the purchased product".
    ///   - failsToLoad: When `true`, `loadProducts(ids:)` throws, to preview the error state.
    public init(
        products: [PaywallProduct] = PreviewPurchaseProvider.sampleProducts,
        purchaseResult: PurchaseResult? = nil,
        restoreResult: RestoreResult = .nothingToRestore,
        delay: Duration = .milliseconds(600),
        failsToLoad: Bool = false
    ) {
        self.products = products
        self.purchaseResult = purchaseResult
        self.restoreResult = restoreResult
        self.delay = delay
        self.failsToLoad = failsToLoad
    }

    public func loadProducts(ids: [String]) async throws -> [PaywallProduct] {
        try await Task.sleep(for: delay)
        if failsToLoad { throw PaywallError.noProductsAvailable }
        return ids.compactMap { id in products.first { $0.id == id } }
    }

    public func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        try await Task.sleep(for: delay)
        return purchaseResult ?? .success(productID: product.id)
    }

    public func restorePurchases() async throws -> RestoreResult {
        try await Task.sleep(for: delay)
        return restoreResult
    }

    /// A provider pre-filled with `sampleProducts`.
    public static let sample = PreviewPurchaseProvider()

    /// Fake products (Turkish lira) — identifiers are placeholders, not real store products.
    public static let sampleProducts: [PaywallProduct] = [
        PaywallProduct(id: "demo.weekly", displayName: "Weekly", price: Decimal(string: "79.99")!,
                       currencyCode: "TRY", period: .weekly),
        PaywallProduct(id: "demo.monthly", displayName: "Monthly", price: Decimal(string: "199.99")!,
                       currencyCode: "TRY", period: .monthly),
        PaywallProduct(id: "demo.yearly", displayName: "Yearly", price: Decimal(string: "599.99")!,
                       currencyCode: "TRY", period: .yearly, introductoryOffer: .freeTrial(.days(3)))
    ]

    public static var sampleProductIDs: [String] { sampleProducts.map(\.id) }
}
