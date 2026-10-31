import SwiftUI

/// A selectable plan row.
///
/// Prices are rendered only through `PriceHierarchy`, so the billed amount is always the
/// most prominent price (bold, primary color, largest style). Calculated equivalents and
/// offer descriptions are smaller, regular weight and secondary color — this is not
/// configurable (Guideline 3.1.2(c)).
public struct PlanCard: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let product: PaywallProduct
    private let isSelected: Bool
    private let typography: PriceTypography
    private let equivalentUnit: SubscriptionPeriod.Unit?
    private let action: () -> Void

    public init(
        product: PaywallProduct,
        isSelected: Bool,
        typography: PriceTypography = .default,
        equivalentUnit: SubscriptionPeriod.Unit? = nil,
        action: @escaping () -> Void
    ) {
        self.product = product
        self.isSelected = isSelected
        self.typography = typography
        self.equivalentUnit = equivalentUnit
        self.action = action
    }

    public var body: some View {
        let hierarchy = PriceHierarchy(
            product: product,
            formatter: PriceFormatter(locale: locale),
            typography: typography,
            equivalentUnit: equivalentUnit
        )
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    titleRow

                    Text(hierarchy.billed.text)
                        .font(hierarchy.billed.font)
                        .foregroundStyle(.primary)

                    ForEach(hierarchy.secondaryLines, id: \.role) { line in
                        Text(line.text)
                            .font(line.font)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
