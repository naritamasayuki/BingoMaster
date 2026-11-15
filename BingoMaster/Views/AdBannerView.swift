import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// 画面下部に固定表示する広告バナー枠コンポーネント（標準 320×50 相当）。
/// 開発方針に基づき、`AppConfig`（環境変数 / Info.plist）から AdMob 広告ユニットIDを安全に読み込み、
/// GoogleMobileAds SDK 導入時は実バナーを描画し、未配信時はアプリのステータスバーとして自然に描画する（Guideline 2.1 プレースホルダー文字列リジェクト対策済み）。
struct AdBannerView: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()

            #if canImport(GoogleMobileAds)
            if let unitID = AppConfig.adMobBannerUnitID {
                GADBannerContainerView(adUnitID: unitID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(uiColor: .secondarySystemBackground))
            } else {
                fallbackBannerContent
            }
            #else
            fallbackBannerContent
            #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ビンゴマスター ステータスバー")
    }

    private var fallbackBannerContent: some View {
        HStack(spacing: 10) {
            Text("INFO")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("ビンゴマスター ｜ イベント・パーティー進行アシスタント")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("近距離P2P自動同期・日本語音声アナウンス・自動保存対応")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.blue.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

#if canImport(GoogleMobileAds)
private struct GADBannerContainerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
#endif
