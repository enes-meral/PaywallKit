import Foundation
@testable import PaywallKit

enum Fixtures {
    static let tr = Locale(identifier: "tr_TR")
    static let en = Locale(identifier: "en_US")

    static func product(
        _ price: String,
        _ currency: String = "TRY",
        period: SubscriptionPeriod?,
        offer: IntroductoryOffer? = nil,
        id: String = "test.product"
    ) -> PaywallProduct {
        PaywallProduct(id: id, displayName: "Test", price: Decimal(string: price)!,
                       currencyCode: currency, period: period, introductoryOffer: offer)
    }

    static let weeklyTRY = product("79.99", period: .weekly, id: "weekly")
    static let monthlyTRY = product("199.99", period: .monthly, id: "monthly")
    static let yearlyTRY = product("599.99", period: .yearly, id: "yearly")
    static let yearlyTrialTRY = product("599.99", period: .yearly, offer: .freeTrial(.days(3)), id: "yearlyTrial")
    static let lifetimeTRY = product("999.99", period: nil, id: "lifetime")
    static let quarterlyUSD = product("29.99", "USD", period: .months(3), id: "quarterly")
    static let yearlyUSD = product("59.99", "USD", period: .yearly, id: "yearlyUSD")

    static let all: [PaywallProduct] = [weeklyTRY, monthlyTRY, yearlyTRY, yearlyTrialTRY,
                                        lifetimeTRY, quarterlyUSD, yearlyUSD]
}

/// Foundation may use narrow/regular no-break spaces in currency output depending on the
/// ICU version. Normalize them so expectations stay readable.
func normalized(_ string: String?) -> String? {
    string?
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{202F}", with: " ")
}
