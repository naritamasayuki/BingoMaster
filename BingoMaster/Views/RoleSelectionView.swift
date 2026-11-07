import SwiftUI

struct RoleSelectionView: View {
    @StateObject private var syncManager = MultipeerSyncManager()
    @State private var selectedRole: MultipeerSyncManager.Role = .none
    @State private var hostViewModel: HostViewModel?
    @State private var playerViewModel: PlayerViewModel?
    @State private var didRestoreInitialRole: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                switch selectedRole {
                case .none:
                    selectionMenuContent
                case .host:
                    if let hostVM = hostViewModel {
                        HostScreenView(viewModel: hostVM) {
                            returnToRoleSelection()
                        }
                    }
                case .player:
                    if let playerVM = playerViewModel {
                        PlayerScreenView(viewModel: playerVM) {
                            returnToRoleSelection()
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !didRestoreInitialRole else { return }
            didRestoreInitialRole = true
            // 参加者がゲーム途中でアプリを強制終了（タスクキル）または再インストールしても、再起動時に自動的に元のロック済みカード画面へ復帰させる
            if let savedRole = BingoStorage.loadActiveRole() {
                if savedRole == "player" {
                    enterPlayerMode()
                    return
                } else if savedRole == "host" {
                    enterHostMode()
                    return
                }
            }
            if !BingoStorage.loadPlayerDrawnNumbers().isEmpty && BingoStorage.loadHostDrawnNumbers().isEmpty {
                enterPlayerMode()
            }
        }
    }

    // MARK: - 起動画面メニュー

    private var selectionMenuContent: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: .systemGroupedBackground),
                    Color.blue.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // タイトルロゴ＆キャッチコピー
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            ForEach(BingoColumn.allCases) { col in
                                Text(col.rawValue)
                                    .font(.title2.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(col.color)
                                    .clipShape(Circle())
                                    .shadow(color: col.color.opacity(0.35), radius: 4, y: 2)
                            }
                        }
                        .padding(.top, 20)

                        Text("ビンゴマスター")
                            .font(.system(size: 32, weight: .black, design: .rounded))

                        Text("インターネット不要！近くの端末と自動につながるビンゴアプリ")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // 役割選択カード
                    VStack(spacing: 16) {
                        // 1. 司会者（ホスト）ボタン
                        Button {
                            enterHostMode()
                        } label: {
                            roleCardView(
                                iconName: "mic.fill",
                                badgeText: "番号を引く・音声読み上げ",
                                title: "司会者（ホスト）ではじめる",
                                description: "ルーレットで1〜75の番号を抽選し、日本語ボイスで読み上げながら周囲の参加者へ出目を自動配信します。",
                                gradientColors: [Color.blue, Color.indigo]
                            )
                        }
                        .buttonStyle(.plain)

                        // 2. 参加者（プレイヤー）ボタン
                        Button {
                            enterPlayerMode()
                        } label: {
                            roleCardView(
                                iconName: "square.grid.3x3.fill",
                                badgeText: "5×5デジタルカードで遊ぶ",
                                title: "参加者（プレイヤー）ではじめる",
                                description: "あなた専用のビンゴカードを発行し、司会者の出目とリアルタイム連動します。手動タップ・自動穴あけの両方に対応！",
                                gradientColors: [Color.orange, Color.pink]
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // 近距離P2P通信の案内ボックス
                    VStack(alignment: .leading, spacing: 8) {
                        Label("ご利用時のポイント", systemImage: "wifi")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("・Wi-Fi と Bluetooth をオンにしておくと、面倒なペアリング操作なしで近くの司会者と自動接続されます。\n・ゲーム途中の参加やアプリ再起動でも、これまでの出目とカードの状態は自動的に復元されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .safeAreaInset(edge: .bottom) {
            AdBannerView()
        }
        .navigationTitle("モード選択")
        .navigationBarHidden(true)
    }

    private func roleCardView(
        iconName: String,
        badgeText: String,
        title: String,
        description: String,
        gradientColors: [Color]
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(badgeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(2)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: gradientColors.first?.opacity(0.35) ?? .clear, radius: 10, y: 5)
    }

    // MARK: - Role Switching

    private func enterHostMode() {
        BingoStorage.saveActiveRole("host")
        syncManager.startHosting()
        let vm = HostViewModel(syncManager: syncManager)
        self.hostViewModel = vm
        self.selectedRole = .host
    }

    private func enterPlayerMode() {
        BingoStorage.saveActiveRole("player")
        syncManager.startBrowsing()
        let vm = PlayerViewModel(syncManager: syncManager)
        self.playerViewModel = vm
        self.selectedRole = .player
    }

    private func returnToRoleSelection() {
        BingoStorage.saveActiveRole("none")
        BingoSpeaker.shared.stopSpeaking()
        syncManager.stop()
        hostViewModel = nil
        playerViewModel = nil
        selectedRole = .none
    }
}
