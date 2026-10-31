import SwiftUI

/// A feature row shown by `DefaultPaywallHeader`.
public struct PaywallFeature: Identifiable {
    public let id = UUID()
    public let systemImage: String
    public let title: LocalizedStringKey

    /// - Parameter title: Looked up in your app's main bundle, like any `Text`.
    public init(systemImage: String, title: LocalizedStringKey) {
        self.systemImage = systemImage
        self.title = title
    }
}

/// A simple header: title, optional subtitle and a feature list.
public struct DefaultPaywallHeader: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let features: [PaywallFeature]

    public init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, features: [PaywallFeature] = []) {
        self.title = title
        self.subtitle = subtitle
        self.features = features
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(features) { feature in
                        Label {
                            Text(feature.title).foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: feature.systemImage).foregroundStyle(.tint)
                        }
                        .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A complete, App Review–friendly paywall.
///
/// Guarantees, independent of configuration and template (`style`):
/// - The close button is visible in the first frame (no delay, no fade-in).
/// - Restore Purchases, Terms of Use and Privacy Policy are pinned outside any scrolling
///   area and always visible — while loading, on error and while scrolling.
/// - Each plan's billed amount is its most prominent price.
/// - The subscription disclosure is shown next to the plan selection.
///
/// Apply `.tint(_:)` to change the accent color of `.classic` and `.stories`.
public struct PaywallView<Header: View>: View {
    @StateObject private var model: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let style: PaywallStyle
    private let header: Header
    private let onDismiss: (() -> Void)?

    /// - Parameters:
    ///   - configuration: Product IDs, legal URLs and price display options.
    ///   - style: Visual template. Defaults to `.classic`.
    ///   - provider: Store backend. Defaults to StoreKit 2.
    ///   - onPurchase: Called with the product ID after a successful, verified purchase.
    ///   - onRestore: Called with the restored product IDs.
    ///   - onDismiss: Called when the close button is tapped. When `nil`, the paywall uses
    ///     `@Environment(\.dismiss)`.
    ///   - header: Your own content above the plans (hero image, title, features…).
    ///     Do not put prices in it — keep pricing inside the plan cards. Not shown by
    ///     `.stories`, whose pages are the content.
    public init(
        configuration: PaywallConfiguration,
        style: PaywallStyle = .classic,
        provider: any PurchaseProvider = StoreKitPurchaseProvider(),
        onPurchase: @escaping (String) -> Void = { _ in },
        onRestore: @escaping (Set<String>) -> Void = { _ in },
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        _model = StateObject(wrappedValue: PaywallViewModel(
            configuration: configuration,
            provider: provider,
            onPurchase: onPurchase,
            onRestore: onRestore
        ))
        self.style = style
        self.header = header()
        self.onDismiss = onDismiss
    }

    public var body: some View {
        let traits = style.traits
        template
            .overlay(alignment: .topTrailing) {
                // Drawn unconditionally, outside every template: visible in the first frame.
                CloseButton(action: close)
                    .padding(.trailing, 12)
                    .padding(.top, 4)
            }
            .modifier(TemplateAppearance(traits: traits))
            .task { await model.loadProducts() }
            .alert(
                alertTitle,
                isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } }),
                presenting: model.alert
            ) { _ in
                Button(l10n.string("alert.ok"), role: .cancel) {}
            } message: { alert in
                Text(alertMessage(for: alert))
            }
    }

    @ViewBuilder
    private var template: some View {
        switch style {
        case .classic:
            ClassicTemplate(model: model, traits: style.traits, header: header)
        case .comparison(let rows):
            ComparisonTemplate(model: model, traits: style.traits, rows: rows, header: header)
        case .vault:
            VaultTemplate(model: model, traits: style.traits, header: header)
        case .stories(let pages):
            StoriesTemplate(model: model, traits: style.traits, pages: pages)
        }
    }

    // MARK: Helpers

    private var l10n: L10n { L10n(locale: locale) }

    private var alertTitle: String {
        switch model.alert {
        case .restored: return l10n.string("alert.restored.title")
        case .nothingToRestore: return l10n.string("alert.nothingToRestore.title")
        case .pending: return l10n.string("alert.pending.title")
        case .failure, .none: return l10n.string("alert.error.title")
        }
    }

    private func alertMessage(for alert: PaywallAlert) -> String {
        switch alert {
        case .restored: return ""
        case .nothingToRestore: return l10n.string("alert.nothingToRestore.message")
        case .pending: return l10n.string("alert.pending.message")
        case .failure(.failedVerification): return l10n.string("alert.verification.message")
        case .failure: return l10n.string("alert.error.message")
        }
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

/// Applies a template's forced color scheme and gold accent, without touching the
/// caller's tint for templates that don't use gold.
private struct TemplateAppearance: ViewModifier {
    let traits: PaywallTemplateTraits

    func body(content: Content) -> some View {
        let tinted = Group {
            if traits.usesGoldAccent {
                content.tint(PaywallPalette.gold)
            } else {
                content
            }
        }
        if let scheme = traits.forcedColorScheme {
            tinted.environment(\.colorScheme, scheme)
        } else {
            tinted
        }
    }
}

extension PaywallView where Header == DefaultPaywallHeader {
    /// Convenience initializer with the built-in header.
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        features: [PaywallFeature] = [],
        configuration: PaywallConfiguration,
        style: PaywallStyle = .classic,
        provider: any PurchaseProvider = StoreKitPurchaseProvider(),
        onPurchase: @escaping (String) -> Void = { _ in },
        onRestore: @escaping (Set<String>) -> Void = { _ in },
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            configuration: configuration,
            style: style,
            provider: provider,
            onPurchase: onPurchase,
            onRestore: onRestore,
            onDismiss: onDismiss
        ) {
            DefaultPaywallHeader(title: title, subtitle: subtitle, features: features)
        }
    }
}

#if DEBUG
private let previewConfiguration = PaywallConfiguration(
    productIDs: PreviewPurchaseProvider.sampleProductIDs,
    termsOfServiceURL: URL(string: "https://example.com/terms")!,
    privacyPolicyURL: URL(string: "https://example.com/privacy")!,
    preselectedProductID: "demo.yearly",
    equivalentPriceUnit: .week
)

private let previewFeatures = [
    PaywallFeature(systemImage: "sparkles", title: "Unlimited projects"),
    PaywallFeature(systemImage: "icloud", title: "Sync across devices"),
    PaywallFeature(systemImage: "nosign", title: "No ads")
]

#Preview("English") {
    PaywallView(title: "Unlock Pro", features: previewFeatures,
                configuration: previewConfiguration, provider: PreviewPurchaseProvider.sample)
        .environment(\.locale, Locale(identifier: "en_US"))
}

#Preview("Türkçe · Dark") {
    PaywallView(title: "Pro'yu Aç", features: previewFeatures,
                configuration: previewConfiguration, provider: PreviewPurchaseProvider.sample)
        .environment(\.locale, Locale(identifier: "tr_TR"))
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    PaywallView(title: "Unlock Pro", features: previewFeatures,
                configuration: previewConfiguration, provider: PreviewPurchaseProvider.sample)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Load error") {
    PaywallView(title: "Unlock Pro", configuration: previewConfiguration,
                provider: PreviewPurchaseProvider(failsToLoad: true))
}
#endif
