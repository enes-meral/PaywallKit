import StoreKit
import StoreKitTest
import XCTest

/// Detects whether the local StoreKit test environment actually works on this machine.
///
/// On some Xcode / simulator runtime combinations, storekitd rejects every `SKTestSession`
/// call (`SKInternalErrorDomain Code=3`) and StoreKit silently falls back to the real
/// sandbox, where the demo products don't exist. In that case the integration tests are
/// skipped with an explicit message instead of failing (or hanging in `AppStore.sync()`).
enum StoreKitTestEnvironment {
    static let productIDs = ["demo.weekly", "demo.monthly", "demo.yearly"]

    static let skipMessage = """
        StoreKit test environment unavailable: SKTestSession could not load products from \
        PaywallKitDemo.storekit (storekitd rejected the session). StoreKitPurchaseProvider was \
        NOT verified end-to-end in this run.
        """

    static func configurationURL(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let bundle = Bundle(for: BundleToken.self)
        return try XCTUnwrap(bundle.url(forResource: "PaywallKitDemo", withExtension: "storekit"),
                             "PaywallKitDemo.storekit must be copied into the test bundle",
                             file: file, line: line)
    }

    /// `true` when a fresh `SKTestSession` can serve the demo products.
    static func sessionCanLoadProducts() async throws -> Bool {
        let session = try SKTestSession(contentsOf: try configurationURL())
        session.resetToDefaultState()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        let products = try await Product.products(for: productIDs)
        return Set(products.map(\.id)) == Set(productIDs)
    }

    private final class BundleToken {}
}
