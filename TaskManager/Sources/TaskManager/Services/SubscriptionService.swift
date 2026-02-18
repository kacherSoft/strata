import SwiftUI
import StoreKit

enum PremiumFeature: String, CaseIterable {
    case kanban
    case recurringTasks
    case customFields
    case aiAttachments
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published var isPremium = false
    @Published var isVIPPurchased = false

    /// Unified entitlement: subscription OR VIP purchase OR admin grant.
    var hasFullAccess: Bool {
        isPremium || isVIPPurchased || isVIPAdminGranted
    }

    /// Feature-specific gating. Currently all premium features share the same entitlement.
    func canUse(_ feature: PremiumFeature) -> Bool { hasFullAccess }

    var accessLabel: String {
        if isVIPPurchased { return "VIP (Lifetime)" }
        if isPremium { return "Pro (Subscription)" }
        #if DEBUG
        if isVIPAdminGranted { return "VIP (Admin Grant)" }
        #endif
        return "Free"
    }

    private var isVIPAdminGranted: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "debug_vip_granted")
        #else
        false
        #endif
    }

    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let productIDs = ["taskmanager_monthly", "taskmanager_yearly"]
    private let vipProductID = "taskmanager_vip_purchase"
    private lazy var allProductIDs = productIDs + [vipProductID]
    private var transactionListenerTask: Task<Void, Never>?

    private init() {
        listenForTransactions()

        Task {
            await fetchProducts()
            await updatePremiumStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func fetchProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: allProductIDs)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePremiumStatus()
            case .pending:
                break
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updatePremiumStatus()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func updatePremiumStatus() async {
        var hasActiveSubscription = false
        var hasVIP = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }

            if productIDs.contains(transaction.productID),
               transaction.expirationDate.map({ $0 > Date() }) ?? true {
                hasActiveSubscription = true
            }

            if transaction.productID == vipProductID {
                hasVIP = true
            }
        }

        isPremium = hasActiveSubscription
        isVIPPurchased = hasVIP
        objectWillChange.send()
    }

    private func listenForTransactions() {
        transactionListenerTask = Task {
            for await result in Transaction.updates {
                guard let transaction = try? checkVerified(result) else { continue }
                await transaction.finish()
                await updatePremiumStatus()
            }
        }
    }

    #if DEBUG
    func toggleVIPAdminGrant() {
        let current = UserDefaults.standard.bool(forKey: "debug_vip_granted")
        UserDefaults.standard.set(!current, forKey: "debug_vip_granted")
        objectWillChange.send()
    }

    var isVIPAdminGrantActive: Bool {
        UserDefaults.standard.bool(forKey: "debug_vip_granted")
    }
    #endif

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw SubscriptionError.failedVerification
        }
    }
}

enum SubscriptionError: Error {
    case failedVerification
}
