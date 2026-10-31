import Foundation

/// A provider-agnostic description of a purchasable product.
///
/// `StoreKitPurchaseProvider` builds these from StoreKit 2 `Product`s; custom providers
/// (RevenueCat, your own backend, …) map their own types into `PaywallProduct`.
public struct PaywallProduct: Identifiable, Hashable, Sendable {
    /// The store product identifier.
    public let id: String
    /// Localized, user-facing name (e.g. "Yearly").
    public let displayName: String
    /// The amount the user is billed each period (e.g. `599.99`).
    public let price: Decimal
    /// ISO 4217 currency code of `price` (e.g. `"TRY"`).
    public let currencyCode: String
    /// Billing period. `nil` means a one-time purchase (e.g. lifetime unlock).
    public let period: SubscriptionPeriod?
    /// Introductory offer the user is eligible for, if any.
    public let introductoryOffer: IntroductoryOffer?

    public init(
        id: String,
        displayName: String,
        price: Decimal,
        currencyCode: String,
        period: SubscriptionPeriod?,
        introductoryOffer: IntroductoryOffer? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.price = price
        self.currencyCode = currencyCode
        self.period = period
        self.introductoryOffer = introductoryOffer
    }

    /// `true` for auto-renewable subscriptions.
    public var isSubscription: Bool { period != nil }
}
