import PaywallKit
import SwiftUI

/// Demo home screen. Uses only fake products and placeholder URLs — no real keys or IDs.
///
/// Launch arguments (handy for screenshots / UI automation):
/// - `-showPaywall` presents the paywall immediately.
/// - `-useStoreKit` starts with the StoreKit provider (run from Xcode so the local
///   `PaywallKitDemo.storekit` configuration is active).
struct ContentView: View {
    enum ProviderKind: String, CaseIterable, Identifiable {
        case preview
        case storeKit
        var id: Self { self }
    }

    @State private var providerKind: ProviderKind =
        ProcessInfo.processInfo.arguments.contains("-useStoreKit") ? .storeKit : .preview
    @State private var showsWeeklyEquivalent = true
    @State private var isPaywallPresented = ProcessInfo.processInfo.arguments.contains("-showPaywall")
    @State private var unlockedProductID: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(
                        unlockedProductID == nil ? "Free plan" : "Pro unlocked",
                        systemImage: unlockedProductID == nil ? "lock" : "checkmark.seal.fill"
                    )
                    .foregroundStyle(unlockedProductID == nil ? Color.secondary : Color.green)
                } header: {
                    Text("Status")
                }

                Section {
                    Picker("Purchase provider", selection: $providerKind) {
                        Text("Preview (fake)").tag(ProviderKind.preview)
                        Text("StoreKit (local .storekit)").tag(ProviderKind.storeKit)
                    }
                    Toggle("Show weekly equivalent", isOn: $showsWeeklyEquivalent)
                } header: {
                    Text("Options")
                } footer: {
                    Text("The StoreKit provider needs PaywallKitDemo.storekit, which Xcode activates when you run the PaywallKitDemo scheme.")
                }

                Section {
                    Button("Show Paywall") { isPaywallPresented = true }
                        .accessibilityIdentifier("demo.showPaywall")
                }
            }
            .navigationTitle("PaywallKit Demo")
        }
        .fullScreenCover(isPresented: $isPaywallPresented) {
            PaywallView(
                title: "Unlock Pro",
                subtitle: "Everything you need, no limits.",
                features: [
                    PaywallFeature(systemImage: "sparkles", title: "Unlimited projects"),
                    PaywallFeature(systemImage: "icloud", title: "Sync across your devices"),
                    PaywallFeature(systemImage: "nosign", title: "No ads, ever")
                ],
                configuration: configuration,
                provider: provider,
                onPurchase: { productID in
                    unlockedProductID = productID
                    isPaywallPresented = false
                },
                onRestore: { productIDs in
                    unlockedProductID = productIDs.first
                }
            )
            .id(providerKind) // rebuild the paywall when the provider changes
        }
    }

    private var configuration: PaywallConfiguration {
        PaywallConfiguration(
            productIDs: ["demo.weekly", "demo.monthly", "demo.yearly"],
            termsOfServiceURL: URL(string: "https://example.com/terms")!,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!,
            preselectedProductID: "demo.yearly",
            equivalentPriceUnit: showsWeeklyEquivalent ? .week : nil
        )
    }

    private var provider: any PurchaseProvider {
        switch providerKind {
        case .preview: return PreviewPurchaseProvider(products: demoProducts)
        case .storeKit: return StoreKitPurchaseProvider()
        }
    }

    /// Fake products with localized names (the App Store would provide these in production).
    private var demoProducts: [PaywallProduct] {
        [
            PaywallProduct(id: "demo.weekly", displayName: String(localized: "Weekly"),
                           price: Decimal(string: "79.99")!, currencyCode: "TRY", period: .weekly),
            PaywallProduct(id: "demo.monthly", displayName: String(localized: "Monthly"),
                           price: Decimal(string: "199.99")!, currencyCode: "TRY", period: .monthly),
            PaywallProduct(id: "demo.yearly", displayName: String(localized: "Yearly"),
                           price: Decimal(string: "599.99")!, currencyCode: "TRY", period: .yearly,
                           introductoryOffer: .freeTrial(.days(3)))
        ]
    }
}

#Preview {
    ContentView()
}
