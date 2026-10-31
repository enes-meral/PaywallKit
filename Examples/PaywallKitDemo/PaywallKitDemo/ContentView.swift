import PaywallKit
import SwiftUI

/// Demo home screen. Uses only fake products and placeholder URLs — no real keys or IDs.
///
/// Launch arguments (handy for screenshots / UI automation):
/// - `-showPaywall` presents the paywall immediately.
/// - `-paywallStyle classic|comparison|vault|stories` picks the template.
/// - `-useStoreKit` starts with the StoreKit provider (run from Xcode so the local
///   `PaywallKitDemo.storekit` configuration is active).
/// - `-slowProducts` makes the fake provider take 3 s to load (to see the loading state).
/// - `-purchaseDelay <seconds>` sets how long the fake provider takes (load and purchase).
struct ContentView: View {
    enum ProviderKind: String, CaseIterable, Identifiable {
        case preview
        case storeKit
        var id: Self { self }
    }

    enum Template: String, CaseIterable, Identifiable {
        case classic, comparison, vault, stories
        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .classic: return "Classic"
            case .comparison: return "Comparison"
            case .vault: return "Vault"
            case .stories: return "Stories"
            }
        }
    }

    private static let arguments = ProcessInfo.processInfo.arguments

    @State private var providerKind: ProviderKind = arguments.contains("-useStoreKit") ? .storeKit : .preview
    @State private var template: Template =
        UserDefaults.standard.string(forKey: "paywallStyle").flatMap(Template.init(rawValue:)) ?? .classic
    @State private var showsWeeklyEquivalent = true
    @State private var isPaywallPresented = arguments.contains("-showPaywall")
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
                    .accessibilityIdentifier("demo.status")
                } header: {
                    Text("Status")
                }

                Section {
                    Picker("Template", selection: $template) {
                        ForEach(Template.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("demo.template")
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
            paywall
                .id("\(providerKind.rawValue)-\(template.rawValue)") // rebuild when options change
        }
    }

    // MARK: Paywalls

    @ViewBuilder
    private var paywall: some View {
        switch template {
        case .classic:
            PaywallView(
                title: "Unlock Pro",
                subtitle: "Everything you need, no limits.",
                features: [
                    PaywallFeature(systemImage: "sparkles", title: "Unlimited projects"),
                    PaywallFeature(systemImage: "icloud", title: "Sync across your devices"),
                    PaywallFeature(systemImage: "nosign", title: "No ads, ever")
                ],
                configuration: configuration(productIDs: allProductIDs),
                provider: provider,
                onPurchase: purchased,
                onRestore: restored
            )

        case .comparison:
            PaywallView(
                configuration: configuration(productIDs: allProductIDs),
                style: .comparison(rows: comparisonRows),
                provider: provider,
                onPurchase: purchased,
                onRestore: restored
            ) {
                VStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Go Pro")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("See what you get with Pro.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }

        case .vault:
            PaywallView(
                configuration: configuration(productIDs: ["demo.monthly", "demo.yearly"]),
                style: .vault,
                provider: provider,
                onPurchase: purchased,
                onRestore: restored
            ) {
                VStack(spacing: 8) {
                    Text("Unlock the Vault")
                        .font(.title.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("All premium tools in one subscription.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }

        case .stories:
            PaywallView(
                configuration: configuration(productIDs: ["demo.monthly", "demo.yearly"]),
                style: .stories(pages: storyPages),
                provider: provider,
                onPurchase: purchased,
                onRestore: restored
            ) {
                EmptyView()
            }
        }
    }

    private var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(title: String(localized: "Projects"), free: .text("3"), pro: .text("∞")),
            ComparisonRow(title: String(localized: "Cloud sync"), free: .notIncluded, pro: .included),
            ComparisonRow(title: String(localized: "Export to PDF"), free: .notIncluded, pro: .included),
            ComparisonRow(title: String(localized: "Themes"), free: .text("2"), pro: .text("20+")),
            ComparisonRow(title: String(localized: "Ad-free"), free: .notIncluded, pro: .included)
        ]
    }

    private var storyPages: [PaywallStoryPage] {
        [
            PaywallStoryPage(caption: String(localized: "Pro · 1 of 3"),
                             title: String(localized: "See the difference"),
                             background: [Color(red: 0.98, green: 0.50, blue: 0.32), Color(red: 0.86, green: 0.24, blue: 0.55),
                                          Color(red: 0.38, green: 0.20, blue: 0.72), Color(red: 0.07, green: 0.05, blue: 0.22)]) {
                BeforeAfterSlider()
            },
            PaywallStoryPage(caption: String(localized: "Pro · 2 of 3"),
                             title: String(localized: "Unlimited projects"),
                             background: [Color(red: 0.05, green: 0.70, blue: 0.72), Color(red: 0.14, green: 0.38, blue: 0.88),
                                          Color(red: 0.30, green: 0.14, blue: 0.60), Color(red: 0.05, green: 0.04, blue: 0.18)]) {
                StackedProjectsVisual()
            },
            PaywallStoryPage(caption: String(localized: "Pro · 3 of 3"),
                             title: String(localized: "20+ themes"),
                             background: [Color(red: 0.98, green: 0.70, blue: 0.25), Color(red: 0.92, green: 0.32, blue: 0.40),
                                          Color(red: 0.45, green: 0.18, blue: 0.55), Color(red: 0.08, green: 0.04, blue: 0.16)]) {
                ThemeGridVisual()
            }
        ]
    }

    // MARK: Configuration

    private let allProductIDs = ["demo.weekly", "demo.monthly", "demo.yearly"]

    private func configuration(productIDs: [String]) -> PaywallConfiguration {
        PaywallConfiguration(
            productIDs: productIDs,
            termsOfServiceURL: URL(string: "https://example.com/terms")!,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!,
            preselectedProductID: "demo.yearly",
            equivalentPriceUnit: showsWeeklyEquivalent ? .week : nil
        )
    }

    private var provider: any PurchaseProvider {
        switch providerKind {
        case .preview:
            let customDelay = UserDefaults.standard.double(forKey: "purchaseDelay")
            let delay: Duration = customDelay > 0 ? .milliseconds(Int(customDelay * 1000))
                : Self.arguments.contains("-slowProducts") ? .seconds(3) : .milliseconds(600)
            return PreviewPurchaseProvider(products: demoProducts, delay: delay)
        case .storeKit:
            return StoreKitPurchaseProvider()
        }
    }

    private func purchased(_ productID: String) {
        unlockedProductID = productID
        isPaywallPresented = false
    }

    private func restored(_ productIDs: Set<String>) {
        unlockedProductID = productIDs.first
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
