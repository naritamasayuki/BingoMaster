import SwiftUI

struct RoleSelectionView: View {
    @StateObject private var syncManager = MultipeerSyncManager()
    @State private var selectedRole: MultipeerSyncManager.Role = .none
    @State private var hostViewModel: HostViewModel?
    @State private var playerViewModel: PlayerViewModel?
    @State private var didRestoreInitialRole: Bool = false
    @State private var showTermsAndPrivacySheet: Bool = false
    @State private var showBugReportSheet: Bool = false
    @State private var showPartyGoodsSheet: Bool = false

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
        .sheet(isPresented: $showTermsAndPrivacySheet) {
            termsAndPrivacySheetView
        }
        .sheet(isPresented: $showBugReportSheet) {
            BugReportSheetView(
                roleLabel: String(localized: "モード選択画面"),
                drawnCount: BingoStorage.loadHostDrawnNumbers().count,
                connectedPeerCount: syncManager.connectedPeerNames.count
            )
        }
        .sheet(isPresented: $showPartyGoodsSheet) {
            PartyGoodsSheetView()
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
                                badgeText: String(localized: "番号を引く・音声読み上げ"),
                                title: String(localized: "司会者（ホスト）ではじめる"),
                                description: String(localized: "ルーレットで1〜75の番号を抽選し、音声ボイスで読み上げながら周囲の参加者へ出目を自動配信します。"),
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
                                badgeText: String(localized: "5×5デジタルカードで遊ぶ"),
                                title: String(localized: "参加者（プレイヤー）ではじめる"),
                                description: String(localized: "あなた専用のビンゴカードを発行し、司会者の出目とリアルタイム連動します。手動タップ・自動穴あけの両方に対応！"),
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

                    // Amazonアソシエイト関連グッズ案内（PR）
                    PartyGoodsBannerCard {
                        showPartyGoodsSheet = true
                    }

                    // 免責事項・プライバシーポリシー確認 ＆ 不具合報告ボタン
                    VStack(spacing: 12) {
                        Button {
                            showBugReportSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "ladybug.fill")
                                    .foregroundStyle(.orange)
                                Text("不具合・ご要望を報告する")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            showTermsAndPrivacySheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                Text("ご利用規約・プライバシーポリシー・免責事項")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
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

    private var termsAndPrivacySheetView: some View {
        NavigationStack {
            List {
                Section("1. アプリの目的と免責事項（非賭博・非懸賞の明示）") {
                    Text("・本アプリ「ビンゴマスター」は、パーティー・懇親会・社内イベント等の会場において、司会者の番号抽選および参加者のビンゴカード管理を補助する進行用ユーティリティツールです。\n・本アプリ内で金銭（リアルマネー）を賭ける行為、オンライン賭博、またはアプリ開発者による懸賞・景品・金品の提供は一切行いません。\n・Apple Inc. は本アプリを用いたイベント、抽選、または景品のスポンサーではなく、一切の関係を有しません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                Section("2. プライバシーとデータの取り扱い") {
                    Text("・本アプリが保存する出目履歴、ビンゴカード状態、ニックネーム、および不正防止用の端末固有IDは、すべてお客様の端末内（UserDefaults および Keychain）にのみ保存されます。\n・司会者と参加者間のデータ同期は、Apple標準の近距離P2P通信（MultipeerConnectivity）を介して会場内の端末間でのみ直接行われ、外部サーバーへ個人情報を送信・収集することはありません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }

                Section("3. アプリ情報") {
                    HStack {
                        Text("アプリ名")
                        Spacer()
                        Text("ビンゴマスター")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    HStack {
                        Text("バージョン")
                        Spacer()
                        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
                        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
                        Text("\(version) (Build \(build))")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .navigationTitle("規約・プライバシー・免責事項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showTermsAndPrivacySheet = false
                    }
                }
            }
        }
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

    // MARK: - モード切替制御

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
