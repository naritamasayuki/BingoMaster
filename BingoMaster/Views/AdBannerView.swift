import AppTrackingTransparency
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Google Mobile Ads SDK の初期化と ATT（App Tracking Transparency）許可リクエストを安全に管理するマネージャ
@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    /// Google 公式 iOS テスト用バナー広告ユニット ID（Debug ビルド時の無効クリック防止用）
    private static let testBannerUnitID = "ca-app-pub-3940256099942544/2435281174"

    @Published private(set) var isInitialized = false
    private var hasStartedFlow = false

    private init() {}

    /// 現在のビルド構成に応じたバナー広告ユニット ID を返す（Debug は公式テスト ID、Release は本番 ID）
    var effectiveBannerUnitID: String? {
        #if DEBUG
        return Self.testBannerUnitID
        #else
        return AppConfig.adMobBannerUnitID
        #endif
    }

    /// アプリが前面化した後に ATT ダイアログを表示し、完了後に Google Mobile Ads SDK を初期化する
    func startAdFlowAfterActive() {
        guard !hasStartedFlow else {
            initializeSDKIfNeeded()
            return
        }
        hasStartedFlow = true

        Task { @MainActor in
            // ウィンドウが完全に前面表示されてから ATT ダイアログを出すための短い待機
            try? await Task.sleep(nanoseconds: 600_000_000)
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                let status = await ATTrackingManager.requestTrackingAuthorization()
                BingoLogger.logInfo(BingoLogger.game, message: "ATTトラッキング許可ステータス: \(status.rawValue)")
            }
            self.initializeSDKIfNeeded()
        }
    }

    private func initializeSDKIfNeeded() {
        guard !isInitialized else { return }
        guard AppConfig.isAdMobConfigured else {
            BingoLogger.logWarning(BingoLogger.game, context: "AdMob アプリIDが未設定のため SDK 初期化をスキップしました")
            return
        }
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start { status in
            let adapterCount = status.adapterStatusesByClassName.count
            BingoLogger.logInfo(BingoLogger.game, message: "Google Mobile Ads SDK 初期化完了 (アダプタ数: \(adapterCount))")
        }
        #endif
        isInitialized = true
    }
}

/// 画面下部に固定表示する広告バナー枠コンポーネント（標準 320×50 相当）。
/// オンラインで AdMob 広告が読み込まれた際は実バナーを表示し、オフラインや未配信時はステータスバーへ安全にフォールバックする。
struct AdBannerView: View {
    @ObservedObject private var adManager = AdMobManager.shared
    @State private var isAdLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ZStack {
                fallbackBannerContent
                    .opacity(isAdLoaded ? 0.0 : 1.0)

                #if canImport(GoogleMobileAds)
                if adManager.isInitialized, let unitID = adManager.effectiveBannerUnitID {
                    AdMobBannerRepresentableView(
                        adUnitID: unitID,
                        isAdLoaded: $isAdLoaded
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .opacity(isAdLoaded ? 1.0 : 0.0)
                }
                #endif
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .onAppear {
            adManager.startAdFlowAfterActive()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAdLoaded ? String(localized: "広告バナー") : String(localized: "ビンゴマスター ステータスバー"))
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

                Text("近距離P2P自動同期・音声アナウンス・自動保存対応")
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
private struct AdMobBannerRepresentableView: UIViewRepresentable {
    let adUnitID: String
    @Binding var isAdLoaded: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isAdLoaded: $isAdLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    final class Coordinator: NSObject, BannerViewDelegate {
        @Binding var isAdLoaded: Bool

        init(isAdLoaded: Binding<Bool>) {
            _isAdLoaded = isAdLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            BingoLogger.logInfo(BingoLogger.game, message: "AdMob バナー広告を受信しました")
            Task { @MainActor in
                self.isAdLoaded = true
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            BingoLogger.logWarning(BingoLogger.game, context: "AdMob バナー広告の取得に失敗したためフォールバック表示を維持します: \(error.localizedDescription)")
            Task { @MainActor in
                self.isAdLoaded = false
            }
        }
    }
}
#endif
