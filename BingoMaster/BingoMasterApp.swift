import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct BingoMasterApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ゲーム進行中の画面スリープを防止
        UIApplication.shared.isIdleTimerDisabled = true

        // Google AdMob 設定状態の検証とSDK初期化
        if AppConfig.isAdMobConfigured {
            BingoLogger.logInfo(BingoLogger.game, message: "Google AdMob ID設定を確認しました (AppID設定済み)")
            #if canImport(GoogleMobileAds)
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            RoleSelectionView()
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }
}
