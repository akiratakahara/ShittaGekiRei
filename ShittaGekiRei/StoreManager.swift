import StoreKit
import Foundation

// MARK: - Product ID
// App Store Connect で登録するIDと合わせること
extension String {
    static let fullUnlockProductID = "com.artvalue.shittagekirei.fullunlock"
}

@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    @Published var isUnlocked = false
    @Published var product: Product?
    @Published var isPurchasing = false
    @Published var errorMessage: String?

    // 無料ユーザーに許可するプリセット起動回数
    static let freeLaunchLimit = 5

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProductAndCheckEntitlement() }
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Load product + check entitlement
    func loadProductAndCheckEntitlement() async {
        async let productFetch = fetchProduct()
        async let entitlementCheck = checkEntitlement()
        let (prod, unlocked) = await (productFetch, entitlementCheck)
        product = prod
        isUnlocked = unlocked
    }

    private func fetchProduct() async -> Product? {
        do {
            let products = try await Product.products(for: [.fullUnlockProductID])
            return products.first
        } catch {
            errorMessage = "商品の取得に失敗しました: \(error.localizedDescription)"
            return nil
        }
    }

    private func checkEntitlement() async -> Bool {
        // currentEntitlement は非消耗型なら購入済みの場合に返る
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == .fullUnlockProductID,
               tx.revocationDate == nil {
                return true
            }
        }
        return false
    }

    // MARK: - Purchase
    func purchase() async {
        guard let product else {
            errorMessage = "商品を読み込み中です。少し待ってから再試行してください。"
            return
        }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let tx):
                    await tx.finish()
                    isUnlocked = true
                case .unverified:
                    errorMessage = "購入の検証に失敗しました。"
                }
            case .userCancelled:
                break // ユーザーキャンセルは何もしない
            case .pending:
                errorMessage = "購入が保留中です。承認後に有効になります。"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入処理中にエラーが発生しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore
    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            isUnlocked = await checkEntitlement()
            if !isUnlocked {
                errorMessage = "復元できる購入履歴が見つかりませんでした。"
            }
        } catch {
            errorMessage = "復元に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Listen for background transactions (family sharing, refunds etc.)
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    if tx.productID == .fullUnlockProductID {
                        await MainActor.run {
                            self.isUnlocked = tx.revocationDate == nil
                        }
                        await tx.finish()
                    }
                }
            }
        }
    }

    // MARK: - Free trial tracking
    var remainingFreeUses: Int {
        let used = UserDefaults.standard.integer(forKey: "freeUseCount")
        return max(0, StoreManager.freeLaunchLimit - used)
    }

    func consumeFreeUse() {
        let used = UserDefaults.standard.integer(forKey: "freeUseCount")
        UserDefaults.standard.set(used + 1, forKey: "freeUseCount")
    }

    var canUseForFree: Bool {
        remainingFreeUses > 0
    }
}
