import SwiftUI

/// Colors shared by the dark templates.
enum PaywallPalette {
    static let gold = Color(red: 0.98, green: 0.79, blue: 0.36)
    static let goldDeep = Color(red: 0.78, green: 0.54, blue: 0.17)
    static let amber = Color(red: 1.0, green: 0.60, blue: 0.16)
    static let night = Color(red: 0.05, green: 0.05, blue: 0.07)
    static let nightRaised = Color(red: 0.10, green: 0.10, blue: 0.12)
    /// Opaque fill of the stories bottom panel.
    static let panel = Color(red: 0.07, green: 0.07, blue: 0.09)
}

/// Loading / error / plan cards — the plan selection used by every template.
struct PlanSelection: View {
    @ObservedObject var model: PaywallViewModel
    let variant: PlanCard.Variant
    /// Show the configuration's preselected product first.
    var preselectedFirst = false

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let l10n = L10n(locale: locale)
        switch model.loadState {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(l10n.string("state.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: variant == .regular ? 160 : 110)
            .accessibilityElement(children: .combine)

        case .failed:
            VStack(spacing: 12) {
                Text(l10n.string("state.error"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(l10n.string("button.retry")) {
                    Task { await model.loadProducts() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: variant == .regular ? 160 : 110)

        case .loaded:
            let layout: AnyLayout = (variant == .regular || dynamicTypeSize.isAccessibilitySize)
                ? AnyLayout(VStackLayout(spacing: variant == .regular ? 12 : 8))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            layout {
                ForEach(preselectedFirst ? model.productsPreselectedFirst : model.products) { product in
                    PlanCard(
                        product: product,
                        isSelected: product.id == model.selectedProductID,
                        typography: model.configuration.typography,
                        equivalentUnit: model.configuration.equivalentPriceUnit,
                        variant: variant
                    ) {
                        model.selectedProductID = product.id
                    }
                    .disabled(model.isBusy)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The standard purchase button.
struct PurchaseButton: View {
    @ObservedObject var model: PaywallViewModel
    /// Label color override, e.g. black on a gold button.
    var labelColor: Color?

    @Environment(\.locale) private var locale

    var body: some View {
        let title = PurchaseTitles(locale: locale, product: model.selectedProduct).button
        Button {
            Task { await model.purchaseSelected() }
        } label: {
            ZStack {
                Text(title).opacity(model.isPurchasing ? 0 : 1)
                if model.isPurchasing { ProgressView().tint(labelColor) }
            }
            .font(.headline)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .foregroundStyle(labelColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.white))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.selectedProduct == nil || model.isBusy)
        .accessibilityLabel(title)
        .accessibilityIdentifier("paywall.purchase")
    }
}

/// Button / slider titles that depend on the selected plan.
struct PurchaseTitles {
    let button: String
    let slide: String

    init(locale: Locale, product: PaywallProduct?) {
        let l10n = L10n(locale: locale)
        let hasTrial = product?.introductoryOffer?.kind == .freeTrial
        button = l10n.string(hasTrial ? "button.startTrial" : "button.continue")
        slide = l10n.string(hasTrial ? "slide.startTrial" : "slide.continue")
    }
}

/// Restore · Terms · Privacy. Renders exactly the items it is given, in order.
struct PaywallFooterLinks: View {
    @ObservedObject var model: PaywallViewModel
    let items: [PaywallFooterItem]

    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(items)
            VStack(spacing: 8) {
                if let first = items.first { link(first) }
                row(Array(items.dropFirst()))
            }
            VStack(spacing: 8) {
                ForEach(items, id: \.self) { link($0) }
            }
        }
    }

    private func row(_ items: [PaywallFooterItem]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                if index > 0 {
                    Text("·").font(.footnote).foregroundStyle(.secondary).accessibilityHidden(true)
                }
                link(item)
            }
        }
    }

    @ViewBuilder
    private func link(_ item: PaywallFooterItem) -> some View {
        let l10n = L10n(locale: locale)
        switch item {
        case .restore:
            RestoreButton { await model.restore() }
                .disabled(model.isPurchasing)
        case .termsOfUse:
            Link(l10n.string("link.terms"), destination: model.configuration.termsOfServiceURL)
                .font(.footnote)
                .accessibilityIdentifier("paywall.terms")
        case .privacyPolicy:
            Link(l10n.string("link.privacy"), destination: model.configuration.privacyPolicyURL)
                .font(.footnote)
                .accessibilityIdentifier("paywall.privacy")
        }
    }
}

/// Container pinned to the bottom of every template: purchase control + footer links (and,
/// for some templates, the disclosure).
///
/// It is opaque — filled with the template's background color — so scrolled content never
/// shows through it. A soft gradient of `fadeHeight` above its top edge blends it into the
/// content. Its text size is capped so it never covers the screen at accessibility sizes.
struct PinnedPaywallFooter<Content: View>: View {
    let fill: Color
    var fadeHeight: CGFloat = 24
    /// Accessibility identifier of the whole pinned area (used by UI tests).
    var identifier: String? = "paywall.pinnedFooter"
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if fadeHeight > 0 {
                LinearGradient(colors: [fill.opacity(0), fill], startPoint: .top, endPoint: .bottom)
                    .frame(height: fadeHeight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            VStack(spacing: 12) { content() }
                .padding(.horizontal, 20)
                .padding(.top, fadeHeight > 0 ? 4 : 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .background(fill.ignoresSafeArea(edges: .bottom))
        }
        .accessibilityElement(children: .contain)
        .modifier(OptionalIdentifier(identifier: identifier))
    }
}

private struct OptionalIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
