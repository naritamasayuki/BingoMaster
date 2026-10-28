import SwiftUI

struct HostScreenView: View {
    @ObservedObject var viewModel: HostViewModel
    @ObservedObject private var speaker = BingoSpeaker.shared
    let onExitRole: () -> Void

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

                    // 3. 直近の出目履歴（横スクロール）＆ゆっくり読み上げボタン
                    recentHistorySection

                    // 4. 1〜75 マスターボード（B・I・N・G・O 列カラー対応）
                    masterBoardSection

                    // 5. リセット＆退出ボタン
                    footerActionsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, viewModel.toastMessage != nil ? 68 : 12)
                .padding(.bottom, 28)
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
                    viewModel.showResetConfirmationAlert = true
                } label: {
                    Label("リセット", systemImage: "arrow.counterclockwise")
                }
                .disabled(viewModel.isSpinning || viewModel.drawnNumbers.isEmpty)
            }
        }
        // 1段階目：リセット確認アラート
        .alert("ゲームをリセットしますか？", isPresented: $viewModel.showResetConfirmationAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("リセットする", role: .destructive) {
                viewModel.confirmResetGame()
            }
        } message: {
            Text("これまでの出目履歴がすべて消去され、接続中の参加者全員のカードもリセットされます。")
        }
        // 2段階目：リセット完了アラート
        .alert("リセット完了", isPresented: $viewModel.showResetCompletedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("出目履歴をクリアし、参加者へリセット通知を送信しました。新しいゲームを始められます。")
        }
    }

    // MARK: - Subviews

    private var connectionAndStatusBar: some View {
        let peerCount = viewModel.syncManager.connectedPeerNames.count
        let bingoPlayers = viewModel.playerStatuses.values.filter { $0.status == .bingo }
        let reachPlayers = viewModel.playerStatuses.values.filter { $0.status == .reach }

        return VStack(spacing: 8) {
            HStack {
                Label(
                    peerCount > 0 ? "接続中の参加者: \(peerCount)人" : "参加者の接続を待機中...",
                    systemImage: peerCount > 0 ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(peerCount > 0 ? Color.green : Color.secondary)

                Spacer()

                Text("残り \(viewModel.remainingNumbers.count) / 75 球")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            if !bingoPlayers.isEmpty || !reachPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bingoPlayers, id: \.playerName) { item in
                            Text("🎊 ビンゴ: \(item.playerName)")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.pink.opacity(0.18))
                                .foregroundStyle(Color.pink)
                                .clipShape(Capsule())
                        }
                        ForEach(reachPlayers, id: \.playerName) { item in
                            Text("🔥 リーチ: \(item.playerName) (\(item.reachLineCount))")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.18))
                                .foregroundStyle(Color.orange)
                                .clipShape(Capsule())
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
                Text("出目履歴（全 \(viewModel.drawnNumbers.count) 個）")
                    .font(.subheadline.weight(.bold))

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
                        Text("🔊 履歴を読み上げ")
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
        Button(role: .destructive) {
            viewModel.showResetConfirmationAlert = true
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
