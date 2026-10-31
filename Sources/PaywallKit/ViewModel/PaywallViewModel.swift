import Foundation

/// Alerts the paywall can show. Text is resolved in the view, using the `\.locale` environment.
enum PaywallAlert: Hashable, Identifiable {
    case restored
    case nothingToRestore
    case pending
    case failure(PaywallError?)

    var id: Self { self }
}

/// State and actions behind `PaywallView`.
@MainActor
final class PaywallViewModel: ObservableObject {
    enum LoadState: Equatable {
        case loading
        case loaded
        case failed
    }

    @Published private(set) var products: [PaywallProduct] = []
    @Published private(set) var loadState: LoadState = .loading
    @Published var selectedProductID: String?
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var alert: PaywallAlert?

    let configuration: PaywallConfiguration
    private let provider: any PurchaseProvider
    private let onPurchase: (String) -> Void
    private let onRestore: (Set<String>) -> Void

    init(
        configuration: PaywallConfiguration,
        provider: any PurchaseProvider,
        onPurchase: @escaping (String) -> Void = { _ in },
        onRestore: @escaping (Set<String>) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.provider = provider
        self.onPurchase = onPurchase
        self.onRestore = onRestore
    }

    var selectedProduct: PaywallProduct? {
        products.first { $0.id == selectedProductID }
    }

    var isBusy: Bool { isPurchasing || isRestoring }

    func loadProducts() async {
        loadState = .loading
        do {
            let loaded = try await provider.loadProducts(ids: configuration.productIDs)
            guard !loaded.isEmpty else { throw PaywallError.noProductsAvailable }
            products = loaded
            if selectedProduct == nil {
                let preselected = configuration.preselectedProductID
                selectedProductID = loaded.first { $0.id == preselected }?.id ?? loaded.first?.id
            }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func purchaseSelected() async {
        guard let product = selectedProduct, !isBusy else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await provider.purchase(product) {
            case .success(let productID):
                onPurchase(productID)
            case .pending:
                alert = .pending
            case .userCancelled:
                break
            }
        } catch {
            alert = .failure(error as? PaywallError)
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            switch try await provider.restorePurchases() {
            case .restored(let productIDs):
                alert = .restored
                onRestore(productIDs)
            case .nothingToRestore:
                alert = .nothingToRestore
            }
        } catch {
            alert = .failure(error as? PaywallError)
        }
    }
}
