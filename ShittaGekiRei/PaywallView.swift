import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var store = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            RadialGradient(
                colors: [Color(hex: "CC0000").opacity(0.15), Color.black],
                center: .top, startRadius: 0, endRadius: 500
            ).ignoresSafeArea()

            VStack(spacing: 0) {

                // Hero
                VStack(spacing: 12) {
                    Text("🔥")
                        .font(.system(size: 64))
                        .padding(.top, 48)

                    Text("叱咤激励")
                        .font(.system(size: 40, weight: .black, design: .serif))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color(hex: "CC0000").opacity(0.7)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: Color(hex: "CC0000").opacity(0.5), radius: 20)

                    Text("フルアンロック")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .kerning(4)
                }

                Spacer().frame(height: 36)

                // Feature list
                VStack(alignment: .leading, spacing: 16) {
                    featureRow("🌅", "月曜・木曜・金曜の定期通知", "逃げ場なし")
                    featureRow("⏰", "カスタムアラーム無制限", "何個でも設定可")
                    featureRow("🗣️", "メッセージ音声読み上げ", "叩き起こし効果倍増")
                    featureRow("📦", "全メッセージパターン解放", "月・木・金 各10パターン")
                    featureRow("🔄", "将来の追加メッセージも含む", "アップデート無料")
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 36)

                // Price
                if let product = store.product {
                    VStack(spacing: 6) {
                        Text("買い切り")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                            .kerning(3)
                        Text(product.displayPrice)
                            .font(.system(size: 46, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                        Text("一度買えば永久に使える")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    ProgressView()
                        .tint(Color(hex: "CC0000"))
                }

                Spacer().frame(height: 28)

                // Buy button
                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack {
                        if store.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("購入する")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [Color(hex: "CC0000"), Color(hex: "8B0000")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(hex: "CC0000").opacity(0.4), radius: 12, y: 4)
                }
                .disabled(store.isPurchasing || store.product == nil)
                .padding(.horizontal, 24)

                // Restore
                Button {
                    Task { await store.restore() }
                } label: {
                    Text("購入を復元する")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                .padding(.top, 14)
                .disabled(store.isPurchasing)

                // Error
                if let error = store.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "CC0000"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                // Legal
                Text("購入はApple IDに請求されます。購入後の返金はApp Storeポリシーに準じます。")
                    .font(.system(size: 10))
                    .foregroundColor(.gray.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
            }
        }
        .onChange(of: store.isUnlocked) { unlocked in
            if unlocked { dismiss() }
        }
    }

    private func featureRow(_ emoji: String, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(sub)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "CC0000"))
        }
    }
}

// MARK: - Free trial banner (MainView上部に表示)
struct FreeTrialBanner: View {
    @StateObject private var store = StoreManager.shared
    @State private var showPaywall = false

    var body: some View {
        if !store.isUnlocked {
            Button { showPaywall = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("無料体験 残り\(store.remainingFreeUses)回 — タップしてアンロック")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: "CC0000").opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "CC0000").opacity(0.4), lineWidth: 1)
                        )
                )
                .foregroundColor(Color(hex: "CC0000"))
            }
            .padding(.horizontal)
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}
