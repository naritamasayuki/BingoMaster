import SwiftUI
import UIKit

@main
struct BingoMasterApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ゲーム進行中の画面スリープを防止
        UIApplication.shared.isIdleTimerDisabled = true
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
