import XCTest
@testable import PaywallKit

@MainActor
final class PaywallViewModelTests: XCTestCase {
    private func configuration(preselected: String? = nil) -> PaywallConfiguration {
        PaywallConfiguration(
            productIDs: PreviewPurchaseProvider.sampleProductIDs,
            termsOfServiceURL: URL(string: "https://example.com/terms")!,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!,
            preselectedProductID: preselected
        )
    }

    func testLoadsProductsInRequestedOrderAndPreselects() async {
        let model = PaywallViewModel(configuration: configuration(preselected: "demo.yearly"),
                                     provider: PreviewPurchaseProvider(delay: .zero))
        XCTAssertEqual(model.loadState, .loading)
        await model.loadProducts()
        XCTAssertEqual(model.loadState, .loaded)
        XCTAssertEqual(model.products.map(\.id), ["demo.weekly", "demo.monthly", "demo.yearly"])
        XCTAssertEqual(model.selectedProductID, "demo.yearly")
    }

    func testFallsBackToFirstProductWhenNoPreselection() async {
        let model = PaywallViewModel(configuration: configuration(), provider: PreviewPurchaseProvider(delay: .zero))
        await model.loadProducts()
        XCTAssertEqual(model.selectedProductID, "demo.weekly")
    }

    func testLoadFailure() async {
        let model = PaywallViewModel(configuration: configuration(),
                                     provider: PreviewPurchaseProvider(delay: .zero, failsToLoad: true))
        await model.loadProducts()
        XCTAssertEqual(model.loadState, .failed)
    }

    func testSuccessfulPurchaseCallsBack() async {
        var purchased: String?
        let model = PaywallViewModel(configuration: configuration(preselected: "demo.monthly"),
                                     provider: PreviewPurchaseProvider(delay: .zero),
                                     onPurchase: { purchased = $0 })
        await model.loadProducts()
        await model.purchaseSelected()
        XCTAssertEqual(purchased, "demo.monthly")
        XCTAssertNil(model.alert)
        XCTAssertFalse(model.isPurchasing)
    }

    func testCancelledPurchaseIsSilent() async {
        var purchased: String?
        let model = PaywallViewModel(configuration: configuration(),
                                     provider: PreviewPurchaseProvider(purchaseResult: .userCancelled, delay: .zero),
                                     onPurchase: { purchased = $0 })
        await model.loadProducts()
        await model.purchaseSelected()
        XCTAssertNil(purchased)
        XCTAssertNil(model.alert)
    }

    func testPendingPurchaseShowsAlert() async {
        let model = PaywallViewModel(configuration: configuration(),
                                     provider: PreviewPurchaseProvider(purchaseResult: .pending, delay: .zero))
        await model.loadProducts()
        await model.purchaseSelected()
        XCTAssertEqual(model.alert, .pending)
    }

    func testRestore() async {
        var restored: Set<String>?
        let model = PaywallViewModel(
            configuration: configuration(),
            provider: PreviewPurchaseProvider(restoreResult: .restored(productIDs: ["demo.yearly"]), delay: .zero),
            onRestore: { restored = $0 }
        )
        await model.restore()
        XCTAssertEqual(restored, ["demo.yearly"])
        XCTAssertEqual(model.alert, .restored)
    }

    func testNothingToRestore() async {
        let model = PaywallViewModel(configuration: configuration(), provider: PreviewPurchaseProvider(delay: .zero))
        await model.restore()
        XCTAssertEqual(model.alert, .nothingToRestore)
    }
}
