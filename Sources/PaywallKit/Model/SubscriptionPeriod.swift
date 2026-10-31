import Foundation

/// The length of a subscription period or an introductory offer period.
public struct SubscriptionPeriod: Hashable, Sendable {
    public enum Unit: Int, CaseIterable, Comparable, Sendable {
        case day, week, month, year

        public static func < (lhs: Unit, rhs: Unit) -> Bool { lhs.rawValue < rhs.rawValue }

        /// Approximate length of one unit, expressed in weeks.
        /// A year is treated as exactly 52 weeks and a month as 52 / 12 weeks, which is the
        /// convention most paywalls use for "per week" equivalents.
        var lengthInWeeks: Decimal {
            switch self {
            case .day: return Decimal(1) / Decimal(7)
            case .week: return 1
            case .month: return Decimal(52) / Decimal(12)
            case .year: return 52
            }
        }
    }

    public let value: Int
    public let unit: Unit

    public init(value: Int, unit: Unit) {
        precondition(value > 0, "SubscriptionPeriod.value must be positive")
        self.value = value
        self.unit = unit
    }

    public static func days(_ value: Int) -> SubscriptionPeriod { .init(value: value, unit: .day) }
    public static func weeks(_ value: Int) -> SubscriptionPeriod { .init(value: value, unit: .week) }
    public static func months(_ value: Int) -> SubscriptionPeriod { .init(value: value, unit: .month) }
    public static func years(_ value: Int) -> SubscriptionPeriod { .init(value: value, unit: .year) }

    public static let weekly = SubscriptionPeriod.weeks(1)
    public static let monthly = SubscriptionPeriod.months(1)
    public static let yearly = SubscriptionPeriod.years(1)

    /// Approximate length of the whole period in weeks.
    var lengthInWeeks: Decimal { Decimal(value) * unit.lengthInWeeks }

    /// How many `unit`s fit in this period (e.g. a year contains 52 weeks).
    func count(of unit: Unit) -> Decimal { lengthInWeeks / unit.lengthInWeeks }
}
