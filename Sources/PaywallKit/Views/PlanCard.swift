import SwiftUI

/// A selectable plan.
///
/// Prices are rendered only through `PriceHierarchy`, so the billed amount is always the
/// most prominent price (bold, primary color, largest style). Calculated equivalents and
/// offer descriptions are smaller, regular weight and secondary color — this is not
/// configurable (Guideline 3.1.2(c)).
public struct PlanCard: View {
    /// Layout of the card.
    public enum Variant: Hashable, Sendable {
        /// Full-width row with a selection indicator on the leading side.
        case regular
        /// Narrow card for side-by-side layouts (segments, horizontal panels).
        /// With the default typography it uses `PriceTypography.compact`.
        case compact

        /// The typography this variant actually renders with. Custom typography is kept
        /// (it is already validated by `PriceTypography`); the default is swapped for
        /// `.compact` on compact cards so prices fit in narrow columns.
        public func resolvedTypography(_ typography: PriceTypography) -> PriceTypography {
            switch self {
            case .regular: return typography
            case .compact: return typography == .default ? .compact : typography
            }
        }

        /// How far a compact card may shrink the billed amount to keep it on one line.
        static let compactBilledMinimumScale: CGFloat = 0.8

        /// Minimum scale for the billed amount, or `nil` when it must not be forced onto
        /// one line. Compact cards shrink the billed amount (never abbreviating units) only
        /// while it stays larger than the secondary lines — otherwise it may wrap instead.
        func billedSingleLineScale(for typography: PriceTypography) -> CGFloat? {
            guard self == .compact else { return nil }
            let resolved = resolvedTypography(typography)
            let shrunk = resolved.billed.defaultPointSize * Self.compactBilledMinimumScale
            return shrunk > resolved.secondary.defaultPointSize ? Self.compactBilledMinimumScale : nil
        }
    }

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let product: PaywallProduct
    private let isSelected: Bool
    private let typography: PriceTypography
    private let equivalentUnit: SubscriptionPeriod.Unit?
    private let variant: Variant
    private let action: () -> Void

    public init(
        product: PaywallProduct,
        isSelected: Bool,
        typography: PriceTypography = .default,
        equivalentUnit: SubscriptionPeriod.Unit? = nil,
        variant: Variant = .regular,
        action: @escaping () -> Void
    ) {
        self.product = product
        self.isSelected = isSelected
        self.typography = typography
        self.equivalentUnit = equivalentUnit
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        let hierarchy = PriceHierarchy(
            product: product,
            formatter: PriceFormatter(locale: locale),
            typography: variant.resolvedTypography(typography),
            equivalentUnit: equivalentUnit
        )
        let shape = RoundedRectangle(cornerRadius: variant == .compact ? 14 : 16, style: .continuous)

        Button(action: action) {
            Group {
                switch variant {
                case .regular: regularLayout(hierarchy)
                case .compact: compactLayout(hierarchy)
                }
            }
            .background(shape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .overlay(
                shape.strokeBorder(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .separator)),
                    lineWidth: isSelected ? 2 : 1
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: hierarchy))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier("paywall.plan.\(product.id)")
    }

    // MARK: Layouts

    private func regularLayout(_ hierarchy: PriceHierarchy) -> some View {
        HStack(alignment: .top, spacing: 12) {
            selectionIndicator.font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                titleRow
                prices(hierarchy)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactLayout(_ hierarchy: PriceHierarchy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(product.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                selectionIndicator.font(.body)
            }
            if let offer = product.introductoryOffer {
                TrialBadge(offer: offer)
            }
            prices(hierarchy)
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Parts

    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func prices(_ hierarchy: PriceHierarchy) -> some View {
        let singleLineScale = dynamicTypeSize.isAccessibilitySize ? nil : variant.billedSingleLineScale(for: typography)
        Text(hierarchy.billed.text)
            .font(hierarchy.billed.font)
            .foregroundStyle(.primary)
            .lineLimit(singleLineScale == nil ? nil : 1)
            .minimumScaleFactor(singleLineScale ?? 1)

        ForEach(hierarchy.secondaryLines, id: \.role) { line in
            Text(line.text)
                .font(line.font)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
        layout {
            Text(product.displayName)
                .font(.headline)
                .foregroundStyle(.primary)
            if let offer = product.introductoryOffer {
                TrialBadge(offer: offer)
            }
        }
    }

    private func accessibilityLabel(for hierarchy: PriceHierarchy) -> String {
        var parts = [product.displayName, hierarchy.billed.accessibilityLabel]
        parts += hierarchy.secondaryLines.map(\.accessibilityLabel)
        return parts.joined(separator: ", ")
    }
}
