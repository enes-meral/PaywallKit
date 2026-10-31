import StoreKit
import XCTest

/// Verifies that the shared `PaywallKitDemo` scheme points at `PaywallKitDemo.storekit`.
/// No `SKTestSession` is created before the check: products can only load if Xcode applied
/// the scheme's StoreKit configuration. (Runs before `StoreKitPurchaseProviderTests`.)
final class SchemeStoreKitConfigurationTests: XCTestCase {
    func testSchemeStoreKitConfigurationIsActive() async throws {
        let ids = StoreKitTestEnvironment.productIDs
        let products = try await Product.products(for: ids)
        if Set(products.map(\.id)) == Set(ids) { return }

        // Products didn't load. Distinguish "wrong path in the scheme" from "the StoreKit
        // test environment doesn't work here at all".
        guard try await StoreKitTestEnvironment.sessionCanLoadProducts() else {
            throw XCTSkip(StoreKitTestEnvironment.skipMessage)
        }
        XCTFail("SKTestSession works, but the scheme's StoreKitConfigurationFileReference does not resolve to PaywallKitDemo.storekit")
    }
}
