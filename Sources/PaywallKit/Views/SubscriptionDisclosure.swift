import SwiftUI

/// Auto-renewal / trial disclosure text required for subscriptions (Guideline 3.1.2).
/// For one-time purchases it states that the purchase is not a subscription.
public struct SubscriptionDisclosure: View {
    @Environment(\.locale) private var locale
    private let product: PaywallProduct?

    public init(product: PaywallProduct?) {
        self.product = product
    }

    public var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: String {
        let l10n = L10n(locale: locale)
        if let product, !product.isSubscription {
            return l10n.string("disclosure.oneTime")
        }
        var text = l10n.string("disclosure.autoRenew")
        if product?.introductoryOffer?.kind == .freeTrial {
            text += " " + l10n.string("disclosure.trial")
        }
        return text
    }
}
