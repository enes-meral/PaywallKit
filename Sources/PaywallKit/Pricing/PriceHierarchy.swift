import SwiftUI

/// Text styles used for prices.
///
/// Enforces App Store Review Guideline 3.1.2(c): the billed amount must be the most
/// prominent price. If you pass a `secondary` style that is as large as (or larger than)
/// `billed`, it is lowered to the largest style below `billed` (and a debug assertion fires).
public struct PriceTypography: Hashable, Sendable {
    /// Style of the billed amount (`₺599,99/yıl`). Rendered bold, in the primary color.
    public let billed: Font.TextStyle
    /// Style of every secondary price line — calculated equivalents and introductory offer
    /// descriptions. Always rendered regular weight, in the secondary color.
    public let secondary: Font.TextStyle

    public static let `default` = PriceTypography(billed: .title2, secondary: .caption)

    /// Smaller styles for narrow, side-by-side plan cards (`PlanCard.Variant.compact`).
    public static let compact = PriceTypography(billed: .headline, secondary: .caption2)

    public init(billed: Font.TextStyle, secondary: Font.TextStyle) {
        let normalized = Self.normalize(billed: billed, secondary: secondary)
        assert(!normalized.secondaryWasLowered,
               "PaywallKit: the secondary price style must be smaller than the billed price style (Guideline 3.1.2(c)). It was lowered automatically.")
        self.billed = normalized.billed
        self.secondary = normalized.secondary
    }

    /// Same as `init(billed:secondary:)` but never asserts. Useful when styles come from
    /// remote configuration and must be corrected silently.
    public static func clamped(billed: Font.TextStyle, secondary: Font.TextStyle) -> PriceTypography {
        let normalized = normalize(billed: billed, secondary: secondary)
        return PriceTypography(billed: normalized.billed, secondary: normalized.secondary)
    }

    static func normalize(billed: Font.TextStyle, secondary: Font.TextStyle)
        -> (billed: Font.TextStyle, secondary: Font.TextStyle, secondaryWasLowered: Bool) {
        // The billed style must leave room for a strictly smaller secondary style.
        let billed = billed.sizeRank == Font.TextStyle.caption2.sizeRank ? Font.TextStyle.caption : billed
        if secondary.sizeRank < billed.sizeRank {
            return (billed, secondary, false)
        }
        return (billed, Font.TextStyle.largestStyle(below: billed.sizeRank), true)
    }
}

/// A single line of price text with its role and style.
public struct PriceLine: Hashable, Sendable {
    public enum Role: Hashable, Sendable {
        /// The amount actually charged each period. Always present, always most prominent.
        case billed
        /// Trial / intro offer description ("3 gün ücretsiz, sonra ₺599,99/yıl").
        case introductoryOffer
        /// Calculated equivalent ("≈ ₺11,54/hafta"). Never the main price.
        case equivalent
    }

    public let role: Role
    public let text: String
    public let accessibilityLabel: String
    public let textStyle: Font.TextStyle

    /// Only the billed amount is prominent (bold, primary color).
    public var isProminent: Bool { role == .billed }

    public var font: Font {
        .system(textStyle, design: .default, weight: isProminent ? .bold : .regular)
    }
}

/// The price lines of a plan, ordered and styled so that the billed amount is always the
/// most prominent. `PlanCard` renders prices exclusively through this type — there is no
/// API to hand it arbitrary price text.
public struct PriceHierarchy: Hashable, Sendable {
    public let billed: PriceLine
    public let introductoryOffer: PriceLine?
    public let equivalent: PriceLine?

    public init(
        product: PaywallProduct,
        formatter: PriceFormatter = PriceFormatter(),
        typography: PriceTypography = .default,
        equivalentUnit: SubscriptionPeriod.Unit? = nil
    ) {
        billed = PriceLine(
            role: .billed,
            text: formatter.billedAmount(for: product),
            accessibilityLabel: formatter.billedAmountAccessibilityLabel(for: product),
            textStyle: typography.billed
        )

        if let text = formatter.introductoryOfferText(for: product),
           let label = formatter.introductoryOfferAccessibilityLabel(for: product) {
            introductoryOffer = PriceLine(role: .introductoryOffer, text: text,
                                          accessibilityLabel: label, textStyle: typography.secondary)
        } else {
            introductoryOffer = nil
        }

        if let unit = equivalentUnit,
           let text = formatter.equivalent(for: product, per: unit),
           let label = formatter.equivalentAccessibilityLabel(for: product, per: unit) {
            equivalent = PriceLine(role: .equivalent, text: text,
                                   accessibilityLabel: label, textStyle: typography.secondary)
        } else {
            equivalent = nil
        }
    }

    /// Secondary lines in display order.
    public var secondaryLines: [PriceLine] { [introductoryOffer, equivalent].compactMap { $0 } }

    /// All lines in display order; the billed amount is always first.
    public var lines: [PriceLine] { [billed] + secondaryLines }

    /// `true` when the billed amount is the only prominent line and every secondary line
    /// uses a strictly smaller text style. Always `true` by construction; exposed for tests.
    public var satisfiesProminenceRule: Bool {
        billed.isProminent && secondaryLines.allSatisfy {
            !$0.isProminent && $0.textStyle.sizeRank < billed.textStyle.sizeRank
        }
    }
}

extension Font.TextStyle {
    /// Relative size of the style at the default Dynamic Type size. `headline` and `body`
    /// share a point size, so they share a rank.
    var sizeRank: Int {
        switch self {
        case .largeTitle: return 9
        case .title: return 8
        case .title2: return 7
        case .title3: return 6
        case .headline, .body: return 5
        case .callout: return 4
        case .subheadline: return 3
        case .footnote: return 2
        case .caption: return 1
        case .caption2: return 0
        @unknown default: return 5
        }
    }

    /// Every iOS text style, largest first.
    static let allIOSStyles: [Font.TextStyle] = [
        .largeTitle, .title, .title2, .title3, .headline, .body,
        .callout, .subheadline, .footnote, .caption, .caption2
    ]

    /// The largest style whose rank is strictly below `rank`.
    static func largestStyle(below rank: Int) -> Font.TextStyle {
        allIOSStyles.first { $0.sizeRank < rank && $0 != .headline } ?? .caption2
    }
}
