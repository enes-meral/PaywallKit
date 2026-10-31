import SwiftUI

/// `.comparison`: dark background, gold accents, Free vs. Pro table with a gold Pro column.
struct ComparisonTemplate<Header: View>: View {
    @ObservedObject var model: PaywallViewModel
    let traits: PaywallTemplateTraits
    let rows: [ComparisonRow]
    let header: Header

    @ScaledMetric(relativeTo: .body) private var closeButtonClearance: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if !rows.isEmpty {
                    ComparisonTable(rows: rows)
                }
                PlanSelection(model: model, variant: traits.planCardVariant)
                SubscriptionDisclosure(product: model.selectedProduct)
            }
            .padding(.horizontal, 20)
            .padding(.top, min(closeButtonClearance, 76))
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(backdrop.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PinnedPaywallFooter(background: AnyShapeStyle(PaywallPalette.night.opacity(0.92))) {
                PurchaseButton(model: model, labelColor: .black)
                PaywallFooterLinks(model: model, items: traits.footerItems)
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            LinearGradient(colors: [PaywallPalette.nightRaised, PaywallPalette.night, .black],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [PaywallPalette.gold.opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 360)
        }
    }
}

/// Free vs. Pro table. The Pro column sits on a vertical gold strip.
struct ComparisonTable: View {
    let rows: [ComparisonRow]

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var freeWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var proWidth: CGFloat = 72

    var body: some View {
        let l10n = L10n(locale: locale)
        ZStack(alignment: .trailing) {
            // Vertical gold strip behind the Pro column.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [PaywallPalette.gold, PaywallPalette.goldDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: proWidth)
                .shadow(color: PaywallPalette.gold.opacity(0.35), radius: 12)

            VStack(spacing: 0) {
                headerRow(l10n)
                ForEach(rows) { row in
                    Divider().overlay(Color.white.opacity(0.08))
                    rowView(row, l10n)
                }
            }
        }
        .padding(.leading, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func headerRow(_ l10n: L10n) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(l10n.string("comparison.free"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: freeWidth)
            Text(l10n.string("comparison.pro"))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.black)
                .frame(width: proWidth)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.vertical, 12)
        .accessibilityHidden(true)
    }

    private func rowView(_ row: ComparisonRow, _ l10n: L10n) -> some View {
        HStack(spacing: 0) {
            Text(row.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 8)
            cell(row.free, onGold: false)
                .frame(width: freeWidth)
            cell(row.pro, onGold: true)
                .frame(width: proWidth)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.format("comparison.row.a11y", row.title,
                                        spoken(row.free, l10n), spoken(row.pro, l10n)))
    }

    @ViewBuilder
    private func cell(_ value: ComparisonValue, onGold: Bool) -> some View {
        switch value {
        case .included:
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(onGold ? AnyShapeStyle(Color.black) : AnyShapeStyle(.secondary))
        case .notIncluded:
            Image(systemName: "minus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(onGold ? AnyShapeStyle(Color.black.opacity(0.5)) : AnyShapeStyle(.tertiary))
        case .text(let text):
            Text(text)
                .font(.subheadline.weight(onGold ? .bold : .regular))
                .foregroundStyle(onGold ? AnyShapeStyle(Color.black) : AnyShapeStyle(.secondary))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func spoken(_ value: ComparisonValue, _ l10n: L10n) -> String {
        switch value {
        case .included: return l10n.string("comparison.included")
        case .notIncluded: return l10n.string("comparison.notIncluded")
        case .text(let text): return text
        }
    }
}
