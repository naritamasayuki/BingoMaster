import SwiftUI

struct HostScreenView: View {
    @ObservedObject var viewModel: HostViewModel
    @ObservedObject private var speaker = BingoSpeaker.shared
    let onExitRole: () -> Void

    @State private var showPastHistorySheet: Bool = false
    @State private var inspectingPlayer: PlayerToHostPayload? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // 1. 接続ステータス＆参加者リーチ・ビンゴ集計バー
                    connectionAndStatusBar

                    // 2. 特大ルーレットボール＆抽選コントロール
                    ballAndControlsSection

                    // 3. 直近の出目履歴（横スクロール・自動保存表示）＆ゆっくり読み上げボタン
                    recentHistorySection

                    // 4. 1〜75 マスターボード（B・I・N・G・O 列カラー対応）
                    masterBoardSection

                    // 5. リセット＆過去ゲーム履歴ボタン
                    footerActionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, viewModel.toastMessage != nil ? 68 : 12)
                .padding(.bottom, 20)
            }

            // 画面上部のトーストバナー（司会アシスト合いの手 / 参加者リーチ・ビンゴ通知）
            if let message = viewModel.toastMessage {
                toastBannerView(message: message, isCelebration: viewModel.toastIsCelebration)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom) {
            AdBannerView()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.toastMessage)
        .navigationTitle("司会者モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("モード選択へ") {
                    onExitRole()
                }
                .font(.subheadline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    viewModel.requestResetGame()
                } label: {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                }
                .disabled(viewModel.isSpinning || viewModel.drawnNumbers.isEmpty)
            }
        }
        // 1回目のリセット確認アラート（初期値＝「いいえ」）
        .alert("ゲームをリセットしますか？（確認 1/2）", isPresented: $viewModel.showFirstResetConfirmationAlert) {
            Button("いいえ", role: .cancel) {}
            Button("はい（最終確認へ）", role: .destructive) {
                viewModel.proceedToSecondResetConfirmation()
            }
        } message: {
            Text("現在のゲームを終了して出目をクリアします。よろしいですか？")
        }
        // 2回目の最終リセット確認アラート（初期値＝「いいえ」）
        .alert("【最終確認】本当にリセットしますか？（確認 2/2）", isPresented: $viewModel.showSecondResetConfirmationAlert) {
            Button("いいえ", role: .cancel) {}
            Button("はい、リセットする", role: .destructive) {
                viewModel.confirmResetGame()
            }
        } message: {
            Text("接続中の参加者全員のカードもリセットされます。（※今回の出目履歴は「過去のゲーム履歴」へ自動保存されます）")
        }
        // リセット完了通知アラート
        .alert("リセット完了", isPresented: $viewModel.showResetCompletedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("今回の履歴を自動保存し、新しいゲームの準備が整いました。")
        }
        // 過去の自動保存されたゲーム履歴シート
        .sheet(isPresented: $showPastHistorySheet) {
            pastGameHistorySheetView
        }
        // 参加者の5×5カード検算・答え合わせシート
        .sheet(item: $inspectingPlayer) { player in
            playerInspectionSheetView(for: player)
        }
    }

    // MARK: - Subviews

    private var connectionAndStatusBar: some View {
        let peerCount = viewModel.syncManager.connectedPeerNames.count
        let savedPlayerCount = viewModel.playerStatuses.count
        let bingoPlayers = viewModel.playerStatuses.values
            .filter { $0.status == .bingo }
            .sorted { $0.playerName < $1.playerName }
        let reachPlayers = viewModel.playerStatuses.values
            .filter { $0.status == .reach }
            .sorted { $0.playerName < $1.playerName }
        let normalPlayers = viewModel.playerStatuses.values
            .filter { $0.status == .normal }
            .sorted { $0.playerName < $1.playerName }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    peerCount > 0
                        ? "接続中: \(peerCount)人（保存済み参加者: \(savedPlayerCount)人）"
                        : (savedPlayerCount > 0 ? "保存済み参加者: \(savedPlayerCount)人（再接続待機中）" : "参加者の接続を待機中..."),
                    systemImage: peerCount > 0 ? "antenna.radiowaves.left.and.right" : "person.2.fill"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(peerCount > 0 ? Color.green : Color.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.icloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("自動保存中・残り \(viewModel.remainingNumbers.count)/75 球")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.playerStatuses.isEmpty {
                Text("💡 参加者名をタップすると5×5カードの答え合わせ（不正検算）ができます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bingoPlayers) { item in
                            Button {
                                inspectingPlayer = item
                            } label: {
                                Text("🎊 ビンゴ: \(item.playerName) (\(item.bingoLineCount)ライン)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.pink.opacity(0.18))
                                    .foregroundStyle(Color.pink)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(reachPlayers) { item in
                            Button {
                                inspectingPlayer = item
                            } label: {
                                let extraNote = item.theoreticalStatus == .bingo ? "・未タップでビンゴ到達!" : (item.untappedDrawnCount > 0 ? "・未タップ\(item.untappedDrawnCount)" : "")
                                Text("🔥 リーチ: \(item.playerName) (\(item.reachLineCount)\(extraNote))")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.18))
                                    .foregroundStyle(Color.orange)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(normalPlayers) { item in
                            Button {
                                inspectingPlayer = item
                            } label: {
                                let extraNote: String = {
                                    if item.theoreticalStatus == .bingo {
                                        return " (⚠️未タップでビンゴ到達)"
                                    } else if item.theoreticalStatus == .reach {
                                        return " (⚠️未タップでリーチ到達)"
                                    } else if item.untappedDrawnCount > 0 {
                                        return " (未タップ\(item.untappedDrawnCount))"
                                    }
                                    return ""
                                }()
                                Text("👤 参加中: \(item.playerName)\(extraNote)")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(Color.blue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var ballAndControlsSection: some View {
        let currentNumber = viewModel.displayNumber
        let column = currentNumber.map { BingoColumn.column(for: $0) }
        let ballColor = column?.color ?? Color.gray.opacity(0.4)

        return VStack(spacing: 16) {
            // 特大ビンゴボール表示
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ballColor.opacity(0.85),
                                ballColor
                            ],
                            center: .topLeading,
                            startRadius: 12,
                            endRadius: 130
                        )
                    )
                    .frame(width: 176, height: 176)
                    .shadow(color: ballColor.opacity(0.45), radius: 14, x: 0, y: 8)

                Circle()
                    .strokeBorder(Color.white.opacity(0.65), lineWidth: 5)
                    .frame(width: 164, height: 164)

                if let number = currentNumber, let col = column {
                    VStack(spacing: 2) {
                        Text("\(col.rawValue)列")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.92))

                        Text("\(number)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                    }
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Text("抽選前")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .scaleEffect(viewModel.isSpinning ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: viewModel.displayNumber)

            // ルーレット演出の長さ（短め / 普通 / 長い）3段階選択
            VStack(spacing: 6) {
                HStack {
                    Label("ルーレットの長さ", systemImage: "timer")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.spinDurationMode.descriptionText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.blue)
                }

                Picker("ルーレットの長さ", selection: $viewModel.spinDurationMode) {
                    ForEach(SpinDurationMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isSpinning)
            }
            .padding(.horizontal, 4)

            // 抽選ボタン
            Button {
                viewModel.drawNextNumber()
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSpinning {
                        ProgressView()
                            .tint(.white)
                        Text("ルーレット抽選中...")
                            .font(.title3.weight(.bold))
                    } else if viewModel.remainingNumbers.isEmpty {
                        Image(systemName: "checkmark.seal.fill")
                        Text("すべての数字を引き終えました")
                            .font(.headline.weight(.bold))
                    } else {
                        Image(systemName: "dice.fill")
                            .font(.title3)
                        Text("次の数字を引く")
                            .font(.title3.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    viewModel.canDrawNext
                        ? LinearGradient(
                            colors: [Color.blue, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        : LinearGradient(
                            colors: [Color.gray, Color.gray.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: viewModel.canDrawNext ? Color.blue.opacity(0.3) : .clear, radius: 8, y: 4)
            }
            .disabled(!viewModel.canDrawNext)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("出目履歴（全 \(viewModel.drawnNumbers.count) 個）")
                        .font(.subheadline.weight(.bold))
                    Text("1球ごとに自動保存されています")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if speaker.isSpeaking {
                    Button {
                        viewModel.stopReadingHistory()
                    } label: {
                        Text("⏹ 停止")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(Color.red)
                            .clipShape(Capsule())
                    }
                } else {
                    Button {
                        viewModel.startReadingHistory()
                    } label: {
                        Text("🔊 履歴をゆっくり読み上げ")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(Capsule())
                    }
                    .disabled(viewModel.drawnNumbers.isEmpty || viewModel.isSpinning)
                }
            }

            if viewModel.drawnNumbers.isEmpty {
                Text("まだ数字が引かれていません。「次の数字を引く」を押してゲームを開始してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.drawnNumbers.reversed().enumerated()), id: \.offset) { index, number in
                            let col = BingoColumn.column(for: number)
                            HStack(spacing: 4) {
                                Text(col.rawValue)
                                    .font(.caption2.weight(.heavy))
                                Text("\(number)")
                                    .font(.callout.weight(.black))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index == 0 ? col.color : col.color.opacity(0.18))
                            .foregroundStyle(index == 0 ? Color.white : col.color)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var masterBoardSection: some View {
        let drawnSet = Set(viewModel.drawnNumbers)

        return VStack(alignment: .leading, spacing: 10) {
            Text("1〜75 出目一覧ボード")
                .font(.subheadline.weight(.bold))

            ForEach(BingoColumn.allCases) { column in
                HStack(spacing: 6) {
                    // 列ヘッダー（B/I/N/G/O）
                    Text(column.rawValue)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 56)
                        .background(column.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // 各列15個の数字を8列×2段のグリッドでコンパクトに表示
                    let numbers = Array(column.numberRange)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8),
                        spacing: 4
                    ) {
                        ForEach(numbers, id: \.self) { num in
                            let isDrawn = drawnSet.contains(num)
                            let isLatest = viewModel.drawnNumbers.last == num
                            Text("\(num)")
                                .font(.caption.weight(isDrawn ? .black : .medium))
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(
                                    isDrawn ? column.color : Color(uiColor: .tertiarySystemFill)
                                )
                                .foregroundStyle(isDrawn ? Color.white : Color.secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            isLatest ? Color.yellow : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footerActionsSection: some View {
        VStack(spacing: 10) {
            if !viewModel.pastGameHistory.isEmpty {
                Button {
                    showPastHistorySheet = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("自動保存された過去のゲーム履歴（\(viewModel.pastGameHistory.count)件）")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            Button(role: .destructive) {
                viewModel.requestResetGame()
            } label: {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("ゲームをリセットする")
                        .font(.subheadline.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(viewModel.isSpinning || viewModel.drawnNumbers.isEmpty)
        }
    }

    private var pastGameHistorySheetView: some View {
        NavigationStack {
            List {
                ForEach(viewModel.pastGameHistory) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.formattedDate)
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text("計 \(record.drawnNumbers.count) 球・参加者 \(record.players.count) 人")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }

                        if !record.players.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(record.players, id: \.playerName) { p in
                                        let labelText: String = {
                                            switch p.status {
                                            case .bingo: return "🎊 \(p.playerName)(ビンゴ)"
                                            case .reach: return "🔥 \(p.playerName)(リーチ\(p.reachLineCount))"
                                            case .normal: return "👤 \(p.playerName)"
                                            }
                                        }()
                                        Text(labelText)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(uiColor: .tertiarySystemFill))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }

                        if !record.drawnNumbers.isEmpty {
                            Text(
                                record.drawnNumbers
                                    .map { "\(BingoColumn.column(for: $0).rawValue)-\($0)" }
                                    .joined(separator: "、")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Button {
                            viewModel.restoreFromPastRecord(record)
                            showPastHistorySheet = false
                        } label: {
                            Label("このゲーム状態（出目・参加者）を復元する", systemImage: "arrow.uturn.backward.circle.fill")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("過去のゲーム履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        showPastHistorySheet = false
                    }
                }
            }
        }
    }

    private func playerInspectionSheetView(for player: PlayerToHostPayload) -> some View {
        let latestPlayer = viewModel.playerStatuses[player.id] ?? player
        let cardNums = viewModel.registeredPlayerCards[latestPlayer.id] ?? latestPlayer.cardNumbers
        let verifiedCells = BingoLogic.reconstructVerifiedCells(
            cardNumbers: cardNums,
            punchedIndices: Set(latestPlayer.punchedIndices),
            hostDrawnNumbers: viewModel.drawnNumbers
        )
        let eval = BingoLogic.evaluate(cells: verifiedCells)

        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 参加者サマリー＆検算結果
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("👤 \(latestPlayer.playerName)")
                                .font(.title3.weight(.black))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                                Text("司会者側で自動検算済み")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: 12) {
                            Text("確定ビンゴ: \(eval.bingoLineCount)ライン")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.pink.opacity(0.16))
                                .foregroundStyle(.pink)
                                .clipShape(Capsule())

                            Text("確定リーチ: \(eval.reachLineCount)ライン")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.16))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())

                            if latestPlayer.untappedDrawnCount > 0 {
                                Text("手動未タップ: \(latestPlayer.untappedDrawnCount)マス")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.25))
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                            }
                        }

                        Text("※この5×5カードは参加開始時に司会者台帳へロック登録されており、途中で変更することはできません。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // 5×5 カードの答え合わせ表示
                    if verifiedCells.count == 25 {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(BingoColumn.allCases) { col in
                                    Text(col.rawValue)
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(col.color)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }

                            let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
                            LazyVGrid(columns: cols, spacing: 6) {
                                ForEach(verifiedCells) { cell in
                                    let col = BingoColumn.allCases[cell.id % 5]
                                    let isBingoCell = eval.bingoCellIDs.contains(cell.id)
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                cell.isPunched
                                                    ? (isBingoCell ? Color.pink : col.color)
                                                    : (cell.shouldHighlight ? Color.yellow.opacity(0.28) : Color(uiColor: .tertiarySystemGroupedBackground))
                                            )

                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                cell.shouldHighlight ? Color.orange : (isBingoCell ? Color.yellow : Color.clear),
                                                lineWidth: 2.5
                                            )

                                        VStack(spacing: 2) {
                                            if cell.isFree {
                                                Text("FREE")
                                                    .font(.caption.weight(.black))
                                                    .foregroundStyle(.white)
                                            } else {
                                                Text("\(cell.number)")
                                                    .font(.title3.weight(.black))
                                                    .foregroundStyle(cell.isPunched ? .white : .primary)

                                                if cell.shouldHighlight {
                                                    Text("未タップ")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.orange)
                                                } else if cell.isPunched {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        }
                                    }
                                    .aspectRatio(1.0, contentMode: .fit)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        Text("参加者のカードデータを同期中です...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }
            .navigationTitle("カードの答え合わせ・検算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        inspectingPlayer = nil
                    }
                }
            }
        }
    }

    private func toastBannerView(message: String, isCelebration: Bool) -> some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            Button {
                viewModel.toastMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isCelebration
                ? LinearGradient(colors: [Color.pink, Color.orange], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.orange, Color(red: 1.0, green: 0.45, blue: 0.0)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
    }
}
