import Foundation
import StoreKit

/// Default `PurchaseProvider` backed by StoreKit 2.
///
/// - Note: This provider handles transactions started from the paywall. Your app should
///   still listen to `Transaction.updates` for its whole lifetime (renewals, Ask to Buy
///   approvals, purchases made on other devices). See the README.
public final class StoreKitPurchaseProvider: PurchaseProvider {
    private let cache = ProductCache()

    public init() {}

    public func loadProducts(ids: [String]) async throws -> [PaywallProduct] {
        let storeProducts = try await Product.products(for: ids)
        await cache.store(storeProducts)

        var mapped: [PaywallProduct] = []
        for product in storeProducts {
            mapped.append(await PaywallProduct(storeKitProduct: product))
        }
        // Keep the order the caller asked for; StoreKit returns products in arbitrary order.
        return mapped.sorted { lhs, rhs in
            (ids.firstIndex(of: lhs.id) ?? .max) < (ids.firstIndex(of: rhs.id) ?? .max)
        }
    }

    public func purchase(_ product: PaywallProduct) async throws -> PurchaseResult {
        guard let storeProduct = await cache.product(for: product.id) else {
            throw PaywallError.productNotFound(id: product.id)
        }
        switch try await storeProduct.purchase() {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            return .success(productID: transaction.productID)
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        @unknown default:
            return .userCancelled
        }
    }

    public func restorePurchases() async throws -> RestoreResult {
        try await AppStore.sync()
        var productIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                productIDs.insert(transaction.productID)
            }
        }
        return productIDs.isEmpty ? .nothingToRestore : .restored(productIDs: productIDs)
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw PaywallError.failedVerification
        }
    }
}

private actor ProductCache {
    private var products: [String: Product] = [:]

    func store(_ newProducts: [Product]) {
        for product in newProducts { products[product.id] = product }
    }

    func product(for id: String) -> Product? { products[id] }
}

extension PaywallProduct {
    init(storeKitProduct product: Product) async {
        var offer: IntroductoryOffer?
        if let subscription = product.subscription,
           let intro = subscription.introductoryOffer,
           await subscription.isEligibleForIntroOffer {
            offer = IntroductoryOffer(storeKitOffer: intro)
        }
        self.init(
            id: product.id,
            displayName: product.displayName,
            price: product.price,
            currencyCode: product.priceFormatStyle.currencyCode,
            period: product.subscription.map { SubscriptionPeriod(storeKitPeriod: $0.subscriptionPeriod) },
            introductoryOffer: offer
        )
    }
}

extension SubscriptionPeriod {
    init(storeKitPeriod period: Product.SubscriptionPeriod) {
        let unit: Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: unit = .month
        }
        self.init(value: period.value, unit: unit)
    }
}

extension IntroductoryOffer {
    init(storeKitOffer offer: Product.SubscriptionOffer) {
        let kind: Kind
        switch offer.paymentMode {
        case .freeTrial: kind = .freeTrial
        case .payAsYouGo: kind = .payAsYouGo
        case .payUpFront: kind = .payUpFront
        default: kind = .payAsYouGo
        }
        self.init(
            kind: kind,
            price: offer.price,
            period: SubscriptionPeriod(storeKitPeriod: offer.period),
            periodCount: offer.periodCount
        )
    }
}
