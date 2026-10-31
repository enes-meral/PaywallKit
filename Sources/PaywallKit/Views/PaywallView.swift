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
/// Guarantees, independent of configuration:
/// - The close button is visible in the first frame (no delay, no fade-in).
/// - Restore Purchases, Terms of Use and Privacy Policy are pinned to the bottom and
///   always visible — while loading, on error and while scrolling.
/// - Each plan's billed amount is its most prominent price.
///
/// Apply `.tint(_:)` to change the accent color.
public struct PaywallView<Header: View>: View {
    @StateObject private var model: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private let header: Header
    private let onDismiss: (() -> Void)?

    /// - Parameters:
    ///   - configuration: Product IDs, legal URLs and price display options.
    ///   - provider: Store backend. Defaults to StoreKit 2.
    ///   - onPurchase: Called with the product ID after a successful, verified purchase.
    ///   - onRestore: Called with the restored product IDs.
    ///   - onDismiss: Called when the close button is tapped. When `nil`, the paywall uses
    ///     `@Environment(\.dismiss)`.
    ///   - header: Your own content above the plans (hero image, title, features…).
    ///     Do not put prices in it — keep pricing inside the plan cards.
    public init(
        configuration: PaywallConfiguration,
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
        self.header = header()
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                plans
                SubscriptionDisclosure(product: model.selectedProduct)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56) // room for the close button
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        .overlay(alignment: .topTrailing) {
            CloseButton(action: close)
                .padding(.trailing, 12)
                .padding(.top, 4)
        }
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

    // MARK: Sections

    @ViewBuilder
    private var plans: some View {
        switch model.loadState {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(l10n.string("state.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
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
            .frame(maxWidth: .infinity, minHeight: 160)

        case .loaded:
            VStack(spacing: 12) {
                ForEach(model.products) { product in
                    PlanCard(
                        product: product,
                        isSelected: product.id == model.selectedProductID,
                        typography: model.configuration.typography,
                        equivalentUnit: model.configuration.equivalentPriceUnit
                    ) {
                        model.selectedProductID = product.id
                    }
                    .disabled(model.isBusy)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task { await model.purchaseSelected() }
            } label: {
                ZStack {
                    Text(purchaseTitle).opacity(model.isPurchasing ? 0 : 1)
                    if model.isPurchasing { ProgressView() }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selectedProduct == nil || model.isBusy)
            .accessibilityLabel(purchaseTitle)
            .accessibilityIdentifier("paywall.purchase")

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    restoreButton
                    Text("·").font(.footnote).foregroundStyle(.secondary).accessibilityHidden(true)
                    legalLinks
                }
                VStack(spacing: 8) {
                    restoreButton
                    legalLinks
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var restoreButton: some View {
        RestoreButton { await model.restore() }
            .disabled(model.isPurchasing)
    }

    private var legalLinks: some View {
        LegalLinks(
            termsURL: model.configuration.termsOfServiceURL,
            privacyURL: model.configuration.privacyPolicyURL
        )
    }

    // MARK: Helpers

    private var l10n: L10n { L10n(locale: locale) }

    private var purchaseTitle: String {
        model.selectedProduct?.introductoryOffer?.kind == .freeTrial
            ? l10n.string("button.startTrial")
            : l10n.string("button.continue")
    }

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

extension PaywallView where Header == DefaultPaywallHeader {
    /// Convenience initializer with the built-in header.
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        features: [PaywallFeature] = [],
        configuration: PaywallConfiguration,
        provider: any PurchaseProvider = StoreKitPurchaseProvider(),
        onPurchase: @escaping (String) -> Void = { _ in },
        onRestore: @escaping (Set<String>) -> Void = { _ in },
        onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            configuration: configuration,
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
