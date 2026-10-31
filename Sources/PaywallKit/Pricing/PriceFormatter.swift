import Foundation

/// Formats prices for display: the billed amount (`₺599,99/yıl`), optional calculated
/// equivalents (`≈ ₺11,54/hafta`) and introductory offer descriptions.
///
/// The formatter's `locale` controls both the number format and the language of the
/// period suffixes. The currency always comes from the product.
public struct PriceFormatter: Sendable {
    public let locale: Locale

    public init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
    }

    private var l10n: L10n { L10n(locale: locale) }

    // MARK: Amounts

    /// A plain currency amount, e.g. `₺599,99`.
    public func amount(_ value: Decimal, currencyCode: String) -> String {
        value.formatted(.currency(code: currencyCode).locale(locale))
    }

    /// The amount the user is actually billed, with its period: `₺599,99/yıl`,
    /// `$29.99 / 3 months`, or `₺999,99 · tek seferlik` for one-time purchases.
    public func billedAmount(for product: PaywallProduct) -> String {
        let price = amount(product.price, currencyCode: product.currencyCode)
        guard let period = product.period else { return l10n.format("price.oneTime", price) }
        return perPeriod(price, period, accessible: false)
    }

    /// VoiceOver-friendly variant of `billedAmount(for:)`, e.g. "yılda ₺599,99".
    public func billedAmountAccessibilityLabel(for product: PaywallProduct) -> String {
        let price = amount(product.price, currencyCode: product.currencyCode)
        guard let period = product.period else { return l10n.format("a11y.price.oneTime", price) }
        return perPeriod(price, period, accessible: true)
    }

    // MARK: Equivalents

    /// The calculated price per `unit` (e.g. per week), or `nil` when the product's billing
    /// period is not longer than `unit` — a weekly plan never shows a "weekly equivalent".
    /// A year counts as 52 weeks and a month as 52/12 weeks.
    public func equivalentAmount(for product: PaywallProduct, per unit: SubscriptionPeriod.Unit) -> Decimal? {
        guard let period = product.period, period.lengthInWeeks > unit.lengthInWeeks else { return nil }
        return product.price / period.count(of: unit)
    }

    /// `≈ ₺11,54/hafta`, or `nil` (see `equivalentAmount(for:per:)`).
    public func equivalent(for product: PaywallProduct, per unit: SubscriptionPeriod.Unit) -> String? {
        guard let value = equivalentAmount(for: product, per: unit) else { return nil }
        let price = amount(value, currencyCode: product.currencyCode)
        return l10n.format("price.approx", perPeriod(price, SubscriptionPeriod(value: 1, unit: unit), accessible: false))
    }

    /// VoiceOver-friendly variant of `equivalent(for:per:)`.
    public func equivalentAccessibilityLabel(for product: PaywallProduct, per unit: SubscriptionPeriod.Unit) -> String? {
        guard let value = equivalentAmount(for: product, per: unit) else { return nil }
        let price = amount(value, currencyCode: product.currencyCode)
        return l10n.format("a11y.price.approx", perPeriod(price, SubscriptionPeriod(value: 1, unit: unit), accessible: true))
    }

    // MARK: Introductory offers

    /// `3 gün ücretsiz, sonra ₺599,99/yıl` — always names the amount billed after the offer.
    public func introductoryOfferText(for product: PaywallProduct) -> String? {
        introText(for: product, accessible: false)
    }

    /// VoiceOver-friendly variant of `introductoryOfferText(for:)`.
    public func introductoryOfferAccessibilityLabel(for product: PaywallProduct) -> String? {
        introText(for: product, accessible: true)
    }

    /// Short badge text: `3 gün ücretsiz` for free trials, `Tanıtım teklifi` otherwise.
    public func badgeText(for offer: IntroductoryOffer) -> String {
        switch offer.kind {
        case .freeTrial: return l10n.format("trial.badge", duration(offer.totalDuration))
        case .payAsYouGo, .payUpFront: return l10n.string("intro.badge")
        }
    }

    /// A localized duration such as `3 days` / `3 gün`.
    public func duration(_ period: SubscriptionPeriod) -> String {
        l10n.format("duration.\(period.unit.key)", period.value)
    }

    // MARK: Private

    private func introText(for product: PaywallProduct, accessible: Bool) -> String? {
        guard let offer = product.introductoryOffer else { return nil }
        let then = accessible ? billedAmountAccessibilityLabel(for: product) : billedAmount(for: product)
        let offerDuration = duration(offer.totalDuration)
        switch offer.kind {
        case .freeTrial:
            return l10n.format("intro.freeTrial", offerDuration, then)
        case .payAsYouGo:
            let price = amount(offer.price, currencyCode: product.currencyCode)
            return l10n.format("intro.discount", perPeriod(price, offer.period, accessible: accessible), offerDuration, then)
        case .payUpFront:
            let price = amount(offer.price, currencyCode: product.currencyCode)
            return l10n.format("intro.discount", price, offerDuration, then)
        }
    }

    private func perPeriod(_ price: String, _ period: SubscriptionPeriod, accessible: Bool) -> String {
        let prefix = accessible ? "a11y.price" : "price"
        if period.value == 1 {
            return l10n.format("\(prefix).per.\(period.unit.key)", price)
        }
        return l10n.format("\(prefix).per.period", price, duration(period))
    }
}

extension SubscriptionPeriod.Unit {
    var key: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }
}
