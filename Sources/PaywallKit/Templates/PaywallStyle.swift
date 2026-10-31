import SwiftUI

/// Visual template of a `PaywallView`.
///
/// Every template keeps the same App Review guarantees: prices rendered only through
/// `PriceHierarchy`, a close button visible from the first frame, Restore / Terms /
/// Privacy pinned outside any scrolling area, and the subscription disclosure next to
/// the plan selection.
public enum PaywallStyle {
    /// The default layout: header, vertical plan list, button. Follows light/dark mode.
    case classic
    /// Dark background with gold accents and a Free vs. Pro comparison table.
    case comparison(rows: [ComparisonRow])
    /// Dark "vault": glowing gold lock with orbit rings, two-part plan segment and a
    /// slide-to-confirm control.
    case vault
    /// Full-screen story pages with auto-advance; plans and the button stay visible in a
    /// fixed bottom panel on every page.
    case stories(pages: [PaywallStoryPage])
}

/// One row of the `.comparison` table.
public struct ComparisonRow: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let title: String
    public let free: ComparisonValue
    public let pro: ComparisonValue

    public init(title: String, free: ComparisonValue, pro: ComparisonValue) {
        self.title = title
        self.free = free
        self.pro = pro
    }
}

/// A cell of the `.comparison` table.
public enum ComparisonValue: Hashable, Sendable {
    case included
    case notIncluded
    /// Short text such as "3" or "Unlimited".
    case text(String)
}

/// One page of the `.stories` template.
public struct PaywallStoryPage: Identifiable {
    public let id = UUID()
    public let caption: String
    public let title: String
    /// Gradient colors of the page background (top to bottom). Use dark colors: text on
    /// story pages is white.
    public let background: [Color]
    let content: AnyView

    public init<Content: View>(
        caption: String,
        title: String,
        background: [Color],
        @ViewBuilder content: () -> Content
    ) {
        self.caption = caption
        self.title = title
        self.background = background
        self.content = AnyView(content())
    }

    public init(caption: String, title: String, background: [Color]) {
        self.init(caption: caption, title: title, background: background) { EmptyView() }
    }
}

// MARK: - Template rules

/// Items of the pinned footer. Every template renders exactly these.
enum PaywallFooterItem: Hashable, CaseIterable {
    case restore
    case termsOfUse
    case privacyPolicy
}

/// Where the subscription disclosure is shown. Either way it is fully visible next to the
/// plan selection, never under the pinned area.
enum PaywallDisclosurePlacement: Hashable {
    /// In the scroll view, directly below the plans.
    case belowPlans
    /// In the opaque pinned area, above the purchase control.
    case pinned
}

/// How the purchase is confirmed.
enum PaywallPurchaseControl: Hashable {
    case button
    case slideToConfirm
}

/// What a template is allowed to vary. Templates read their layout decisions from here,
/// and the guarantees that must not vary are constants — the unit tests check them for
/// every style.
struct PaywallTemplateTraits {
    let planCardVariant: PlanCard.Variant
    let purchaseControl: PaywallPurchaseControl
    /// `nil` follows the system appearance.
    let forcedColorScheme: ColorScheme?
    let usesGoldAccent: Bool
    /// Opaque fill of the pinned area — the template's background color behind it.
    let footerFill: Color
    let disclosurePlacement: PaywallDisclosurePlacement
    /// Show the preselected plan first.
    let preselectedPlanFirst: Bool

    // Guarantees — identical for every template.
    let footerItems: [PaywallFooterItem] = PaywallFooterItem.allCases
    let footerIsPinnedOutsideScrollView = true
    let closeButtonAppearanceDelay: TimeInterval = 0
    let disclosureIsNextToPlans = true

    /// Typography the plan cards actually render with.
    func priceTypography(for configuration: PaywallConfiguration) -> PriceTypography {
        planCardVariant.resolvedTypography(configuration.typography)
    }
}

extension PaywallStyle {
    var traits: PaywallTemplateTraits {
        switch self {
        case .classic:
            return PaywallTemplateTraits(planCardVariant: .regular, purchaseControl: .button,
                                         forcedColorScheme: nil, usesGoldAccent: false,
                                         footerFill: Color(uiColor: .systemGroupedBackground),
                                         disclosurePlacement: .belowPlans, preselectedPlanFirst: false)
        case .comparison:
            return PaywallTemplateTraits(planCardVariant: .regular, purchaseControl: .button,
                                         forcedColorScheme: .dark, usesGoldAccent: true,
                                         footerFill: .black,
                                         disclosurePlacement: .pinned, preselectedPlanFirst: true)
        case .vault:
            return PaywallTemplateTraits(planCardVariant: .compact, purchaseControl: .slideToConfirm,
                                         forcedColorScheme: .dark, usesGoldAccent: true,
                                         footerFill: PaywallPalette.night,
                                         disclosurePlacement: .belowPlans, preselectedPlanFirst: false)
        case .stories:
            return PaywallTemplateTraits(planCardVariant: .compact, purchaseControl: .button,
                                         forcedColorScheme: .dark, usesGoldAccent: false,
                                         footerFill: PaywallPalette.panel,
                                         disclosurePlacement: .pinned, preselectedPlanFirst: false)
        }
    }
}
