import SwiftUI

/// アプリのルートタブ画面（4つの主要機能を統合）
struct MainTabView: View {
    @EnvironmentObject private var storage: SafetyStorage
    @EnvironmentObject private var buzzer: SecurityBuzzerManager

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $storage.selectedTab) {
                SafetyWebPortalView()
                    .tabItem {
                        Label("不審者サイト", systemImage: "globe.asia.australia.fill")
                    }
                    .tag(0)

                SafetyMapView()
                    .tabItem {
                        Label("防犯マップ", systemImage: "map.fill")
                    }
                    .tag(1)

                SavedAndHistoryView()
                    .tabItem {
                        Label("保存・履歴", systemImage: "bookmark.fill")
                    }
                    .tag(2)

                SecurityToolsView()
                    .tabItem {
                        Label("防犯ブザー・設定", systemImage: "light.beacon.max.fill")
                    }
                    .tag(3)
            }

            // 防犯ブザー鳴動中はどのタブにいても上部に緊急停止バーを表示
            if buzzer.isBuzzerActive {
                HStack(spacing: 10) {
                    Image(systemName: "light.beacon.max.fill")
                        .foregroundStyle(.white)
                    Text("防犯ブザー鳴動中！")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        buzzer.stopBuzzer()
                    } label: {
                        Text("停止する")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white)
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(buzzer.isFlashScreenRed ? Color.red : Color.orange)
                .shadow(radius: 4)
            }
        }
    }
}
