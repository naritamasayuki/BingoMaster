import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// 画面下部に固定表示する広告バナー枠コンポーネント（標準 320×50 相当）。
/// 開発方針に基づき、`AppConfig`（環境変数 / Info.plist）から AdMob 広告ユニットIDを安全に読み込み、
/// GoogleMobileAds SDK 導入時は実バナーを描画し、未リンク時や審査待機中もレイアウト崩れを防ぐ枠を表示する。
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
                placeholderBannerContent
            }
            #else
            placeholderBannerContent
            #endif
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("スポンサー広告スペース")
    }

    private var placeholderBannerContent: some View {
        HStack(spacing: 10) {
            Text("広告")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    AppConfig.isAdMobConfigured
                        ? "Google AdMob バナー広告（配信準備完了）"
                        : "スポンサー広告スペース（320×50 バナー枠）"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

                Text(
                    AppConfig.isAdMobConfigured
                        ? "AdMob ユニット連携済み・審査完了後に自動配信されます"
                        : "ここにバナー広告が表示されます"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "megaphone.fill")
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
