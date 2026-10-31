import Foundation

/// An introductory offer attached to a subscription (free trial or discounted start).
public struct IntroductoryOffer: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The user pays nothing for the offer duration.
        case freeTrial
        /// The user pays `price` every `period`, for `periodCount` periods.
        case payAsYouGo
        /// The user pays `price` once, up front, for the whole offer duration.
        case payUpFront
    }

    public let kind: Kind
    /// Price of the offer. `0` for free trials.
    public let price: Decimal
    public let period: SubscriptionPeriod
    public let periodCount: Int

    public init(kind: Kind, price: Decimal = 0, period: SubscriptionPeriod, periodCount: Int = 1) {
        precondition(periodCount > 0, "IntroductoryOffer.periodCount must be positive")
        self.kind = kind
        self.price = kind == .freeTrial ? 0 : price
        self.period = period
        self.periodCount = periodCount
    }

    /// Convenience initializer for a free trial, e.g. `.freeTrial(.days(3))`.
    public static func freeTrial(_ period: SubscriptionPeriod) -> IntroductoryOffer {
        IntroductoryOffer(kind: .freeTrial, period: period)
    }

    /// Total duration of the offer (period × periodCount).
    public var totalDuration: SubscriptionPeriod {
        SubscriptionPeriod(value: period.value * periodCount, unit: period.unit)
    }
}
