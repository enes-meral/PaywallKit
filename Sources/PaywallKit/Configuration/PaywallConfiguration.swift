import Foundation

/// Everything `PaywallView` needs that is not visual content.
///
/// Terms of Use and Privacy Policy URLs are required, non-optional parameters: App Review
/// rejects subscription paywalls without them (Guideline 3.1.2), so a paywall without them
/// cannot be built.
public struct PaywallConfiguration: Sendable {
    /// Store product identifiers, in display order.
    public var productIDs: [String]
    public let termsOfServiceURL: URL
    public let privacyPolicyURL: URL
    /// Product selected when the paywall opens. Defaults to the first product.
    public var preselectedProductID: String?
    /// When set, plans longer than this unit show a small, secondary calculated equivalent
    /// (e.g. `.week` → "≈ ₺11,54/hafta"). `nil` (default) shows no equivalent.
    public var equivalentPriceUnit: SubscriptionPeriod.Unit?
    /// Price text styles. The billed amount is always kept the most prominent.
    public var typography: PriceTypography

    public init(
        productIDs: [String],
        termsOfServiceURL: URL,
        privacyPolicyURL: URL,
        preselectedProductID: String? = nil,
        equivalentPriceUnit: SubscriptionPeriod.Unit? = nil,
        typography: PriceTypography = .default
    ) {
        self.productIDs = productIDs
        self.termsOfServiceURL = termsOfServiceURL
        self.privacyPolicyURL = privacyPolicyURL
        self.preselectedProductID = preselectedProductID
        self.equivalentPriceUnit = equivalentPriceUnit
        self.typography = typography
    }
}
