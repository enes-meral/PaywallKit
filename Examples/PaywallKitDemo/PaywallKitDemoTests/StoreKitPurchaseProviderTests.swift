import PaywallKit
import StoreKit
import StoreKitTest
import XCTest

/// End-to-end tests for `StoreKitPurchaseProvider` against the local
/// `PaywallKitDemo.storekit` configuration (no App Store, no real products).
final class StoreKitPurchaseProviderTests: XCTestCase {
    private static let productIDs = StoreKitTestEnvironment.productIDs

    private var session: SKTestSession!
    private var provider: StoreKitPurchaseProvider!

    private static var environmentAvailable: Bool?

    override func setUp() async throws {
        if Self.environmentAvailable == nil {
            Self.environmentAvailable = try await StoreKitTestEnvironment.sessionCanLoadProducts()
        }
        guard Self.environmentAvailable == true else {
            throw XCTSkip(StoreKitTestEnvironment.skipMessage)
        }

        session = try SKTestSession(contentsOf: try StoreKitTestEnvironment.configurationURL())
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        provider = StoreKitPurchaseProvider()
    }

    override func tearDownWithError() throws {
        session?.clearTransactions()
        session = nil
        provider = nil
    }

    // MARK: loadProducts

    func testLoadProductsReturnsAllThreeWithPricesAndPeriods() async throws {
        let products = try await provider.loadProducts(ids: Self.productIDs)

        XCTAssertEqual(products.map(\.id), Self.productIDs, "Products keep the requested order")
        guard products.count == 3 else { return XCTFail("Expected 3 products, got \(products.count)") }

        let weekly = products[0], monthly = products[1], yearly = products[2]
        XCTAssertEqual(weekly.displayName, "Weekly")
        XCTAssertEqual(weekly.price, Decimal(string: "1.99"))
        XCTAssertEqual(weekly.period, .weekly)
        XCTAssertNil(weekly.introductoryOffer)

        XCTAssertEqual(monthly.displayName, "Monthly")
        XCTAssertEqual(monthly.price, Decimal(string: "4.99"))
        XCTAssertEqual(monthly.period, .monthly)
        XCTAssertNil(monthly.introductoryOffer)

        XCTAssertEqual(yearly.displayName, "Yearly")
        XCTAssertEqual(yearly.price, Decimal(string: "29.99"))
        XCTAssertEqual(yearly.period, .yearly)
        XCTAssertEqual(yearly.introductoryOffer, .freeTrial(.days(3)))

        XCTAssertEqual(Set(products.map(\.currencyCode)), ["USD"])
    }

    func testLoadProductsIgnoresUnknownIdentifiers() async throws {
        let products = try await provider.loadProducts(ids: Self.productIDs + ["demo.doesNotExist"])
        XCTAssertEqual(products.map(\.id), Self.productIDs)
    }

    func testLoadedProductsFormatWithBilledAmountFirst() async throws {
        let yearly = try await loadedProduct("demo.yearly")
        let formatter = PriceFormatter(locale: Locale(identifier: "en_US"))
        let hierarchy = PriceHierarchy(product: yearly, formatter: formatter, equivalentUnit: .week)

        XCTAssertEqual(hierarchy.billed.text, "$29.99/year")
        XCTAssertEqual(hierarchy.introductoryOffer?.text, "Free for 3 days, then $29.99/year")
        XCTAssertEqual(hierarchy.equivalent?.text, "≈ $0.58/week")
        XCTAssertTrue(hierarchy.satisfiesProminenceRule)
    }

    func testLoadProductsFailureThrows() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)

        await assertThrows { _ = try await self.provider.loadProducts(ids: Self.productIDs) }
    }

    // MARK: purchase

    func testPurchaseSucceedsAndFinishesTransaction() async throws {
        let monthly = try await loadedProduct("demo.monthly")

        let result = try await provider.purchase(monthly)

        XCTAssertEqual(result, .success(productID: "demo.monthly"))
        let unfinished = await unfinishedTransactionIDs()
        XCTAssertTrue(unfinished.isEmpty, "The provider must finish the transaction, unfinished: \(unfinished)")
        let entitled = await entitledProductIDs()
        XCTAssertEqual(entitled, ["demo.monthly"])
        XCTAssertEqual(session.allTransactions().count, 1)
    }

    func testIntroOfferIsHiddenAfterUserUsedIt() async throws {
        let yearly = try await loadedProduct("demo.yearly")
        XCTAssertNotNil(yearly.introductoryOffer)

        _ = try await provider.purchase(yearly)

        let reloaded = try await StoreKitPurchaseProvider().loadProducts(ids: ["demo.yearly"])
        XCTAssertNil(reloaded.first?.introductoryOffer, "An ineligible user must not see the free trial")
    }

    func testAskToBuyReturnsPendingAndGrantsNothing() async throws {
        session.askToBuyEnabled = true
        let weekly = try await loadedProduct("demo.weekly")

        let result = try await provider.purchase(weekly)

        XCTAssertEqual(result, .pending)
        let entitled = await entitledProductIDs()
        XCTAssertTrue(entitled.isEmpty)
    }

    func testFailedPurchaseThrowsAndGrantsNothing() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let weekly = try await loadedProduct("demo.weekly")

        await assertThrows { _ = try await self.provider.purchase(weekly) }

        let entitled = await entitledProductIDs()
        XCTAssertTrue(entitled.isEmpty)
    }

    func testProductUnavailableThrows() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.purchase(.productUnavailable), forAPI: .purchase)
        let weekly = try await loadedProduct("demo.weekly")

        await assertThrows { _ = try await self.provider.purchase(weekly) }
    }

    /// StoreKit can report a cancellation by *throwing* `StoreKitError.userCancelled`
    /// instead of returning `.userCancelled`. Either way it is not an error for the user.
    func testUserCancellationErrorIsReportedAsCancelledNotAsFailure() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let weekly = try await loadedProduct("demo.weekly")

        let result = try await provider.purchase(weekly)

        XCTAssertEqual(result, .userCancelled)
    }

    func testUnverifiedTransactionIsRejected() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        let weekly = try await loadedProduct("demo.weekly")

        do {
            _ = try await provider.purchase(weekly)
            XCTFail("An unverified transaction must not be reported as a success")
        } catch {
            XCTAssertEqual(error as? PaywallError, .failedVerification)
        }
    }

    // MARK: restorePurchases

    func testRestoreReturnsProductPurchasedThroughProvider() async throws {
        let yearly = try await loadedProduct("demo.yearly")
        _ = try await provider.purchase(yearly)

        let result = try await StoreKitPurchaseProvider().restorePurchases()

        XCTAssertEqual(result, .restored(productIDs: ["demo.yearly"]))
    }

    func testRestoreReturnsPurchaseMadeElsewhere() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("buyProduct(identifier:) needs iOS 17") }
        // Simulates a purchase made on another device / outside the paywall.
        try await session.buyProduct(identifier: "demo.weekly")

        let result = try await provider.restorePurchases()

        XCTAssertEqual(result, .restored(productIDs: ["demo.weekly"]))
    }

    func testRestoreWithNoPurchasesReturnsNothingToRestore() async throws {
        let result = try await provider.restorePurchases()
        XCTAssertEqual(result, .nothingToRestore)
    }

    func testRestoreFailureThrows() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("Simulated errors need iOS 17") }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)

        await assertThrows { _ = try await self.provider.restorePurchases() }
    }

    // MARK: Helpers

    private func loadedProduct(_ id: String) async throws -> PaywallProduct {
        let products = try await provider.loadProducts(ids: Self.productIDs)
        return try XCTUnwrap(products.first { $0.id == id }, "\(id) not loaded")
    }

    private func entitledProductIDs() async -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { ids.insert(transaction.productID) }
        }
        return ids
    }

    private func unfinishedTransactionIDs() async -> [String] {
        var ids: [String] = []
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result { ids.append(transaction.productID) }
        }
        return ids
    }

    private func assertThrows(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("Expected an error", file: file, line: line)
        } catch {}
    }
}

/// Checks that need no StoreKit test environment (they never reach the store), so they run
/// even when `StoreKitPurchaseProviderTests` is skipped.
final class StoreKitPurchaseProviderOfflineTests: XCTestCase {
    func testPurchasingAProductTheProviderDidNotLoadThrows() async {
        let notLoaded = PaywallProduct(id: "demo.weekly", displayName: "Weekly", price: 1,
                                       currencyCode: "USD", period: .weekly)
        do {
            _ = try await StoreKitPurchaseProvider().purchase(notLoaded)
            XCTFail("Expected productNotFound")
        } catch {
            XCTAssertEqual(error as? PaywallError, .productNotFound(id: "demo.weekly"))
        }
    }
}
