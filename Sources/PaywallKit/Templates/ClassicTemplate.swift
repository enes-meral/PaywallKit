import SwiftUI

/// `.classic`: header, vertical plan list, disclosure; button and links pinned below.
struct ClassicTemplate<Header: View>: View {
    @ObservedObject var model: PaywallViewModel
    let traits: PaywallTemplateTraits
    let header: Header

    @ScaledMetric(relativeTo: .body) private var closeButtonClearance: CGFloat = 56

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                PlanSelection(model: model, variant: traits.planCardVariant)
                SubscriptionDisclosure(product: model.selectedProduct)
            }
            .padding(.horizontal, 20)
            .padding(.top, min(closeButtonClearance, 76)) // room for the (size-capped) close button
            .padding(.bottom, 16)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PinnedPaywallFooter(fill: traits.footerFill) {
                PurchaseButton(model: model)
                PaywallFooterLinks(model: model, items: traits.footerItems)
            }
        }
    }
}
