//
//  StoreManager.swift
//  SwiftPDF
//

import Combine
import Foundation
import StoreKit
import os

/// Single source of truth for what the user has purchased. `ProManager` mirrors
/// `isPro` from here so the rest of the app keeps calling `ProManager.shared.isPro`.
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    static let lifetimeID = "JimWas.SwiftPDF.pro.lifetime"
    static let monthlyID = "JimWas.SwiftPDF.pro.monthly"
    static let annualID = "JimWas.SwiftPDF.pro.annual"
    static let productIDs = [monthlyID, annualID, lifetimeID]

    enum PurchaseState: Equatable {
        case idle
        case purchasing(String)
        case error(String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productLoadError: String?
    @Published var purchaseState: PurchaseState = .idle

    private let logger = Logger(subsystem: "JimWas.SwiftPDF", category: "StoreManager")
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await updateEntitlements()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var annualProduct: Product? { products.first { $0.id == Self.annualID } }
    var lifetimeProduct: Product? { products.first { $0.id == Self.lifetimeID } }

    func loadProducts(force: Bool = false) async {
        if isLoadingProducts { return }
        if !force, !products.isEmpty { return }

        isLoadingProducts = true
        productLoadError = nil
        defer { isLoadingProducts = false }

        do {
            let loadedProducts = try await fetchProductsWithTimeout()
                .sorted { $0.price < $1.price }
            products = loadedProducts
            if loadedProducts.isEmpty {
                productLoadError = "No Pro plans were returned by the App Store. Check that the purchase product IDs are active in App Store Connect, or select SwiftPDF.storekit in the Xcode run scheme for local testing."
            }
        } catch StoreError.productLoadTimedOut {
            logger.error("Timed out loading products")
            productLoadError = "The App Store took too long to return plans. Check your connection and try again."
            purchaseState = .error(productLoadError ?? "Couldn't load store prices.")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            productLoadError = "Couldn't load store prices. Check your connection and try again."
            purchaseState = .error(productLoadError ?? "Couldn't load store prices.")
        }
    }

    func purchase(_ product: Product) async {
        purchaseState = .purchasing(product.id)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateEntitlements()
                purchaseState = .idle
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch StoreError.failedVerification {
            logger.error("Purchase failed verification for product \(product.id)")
            purchaseState = .error("We couldn't verify that purchase. Please try again.")
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseState = .error(error.localizedDescription)
        }
    }

    func restorePurchases() async {
        purchaseState = .purchasing("restore")
        do {
            try await AppStore.sync()
            await updateEntitlements()
            purchaseState = .idle
            if !isPro {
                purchaseState = .error("No previous purchases were found for this Apple ID.")
            }
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            purchaseState = .error("Restore failed. Please try again.")
        }
    }

    func updateEntitlements() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
        isPro = !purchased.isEmpty
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self, let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.updateEntitlements()
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func fetchProductsWithTimeout() async throws -> [Product] {
        let productIDs = Self.productIDs
        return try await withThrowingTaskGroup(of: [Product].self) { group in
            group.addTask {
                try await Product.products(for: productIDs)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 12_000_000_000)
                throw StoreError.productLoadTimedOut
            }

            guard let products = try await group.next() else { return [] }
            group.cancelAll()
            return products
        }
    }
}

enum StoreError: Error {
    case failedVerification
    case productLoadTimedOut
}
