import SwiftUI

struct PlayerScreenView: View {
    @ObservedObject var viewModel: PlayerViewModel
    let onExitRole: () -> Void

    @State private var isEditingName: Bool = false
    @State private var draftName: String = ""
    @State private var pulseAnimation: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    // 1. 接続ステータス＆司会者の最新出目バー
                    connectionAndLatestNumberHeader

                    // 2. 「⚡ 自動穴あけモード」切替トグル＆操作ガイド
                    autoPunchToggleSection

                    // 3. 手動モード時の「🎯 タップして開ける！」通知バナー
                    if !viewModel.isAutoPunch && viewModel.highlightedCellCount > 0 {
                        manualTapPromptBanner
                    }

                    // 4. リーチ / ビンゴ達成バナー
                    if let bannerText = viewModel.celebrationBannerText {
                        celebrationBanner(text: bannerText, isBingo: viewModel.evaluation.status == .bingo)
                    }

                    // 5. 5×5 デジタルビンゴカード
                    bingoCardGridSection

                    // 6. 出目履歴（横スクロール）＆カード交換ボタン
                    playerFooterSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }

            // ビンゴ達成時の紙吹雪エフェクト
            if viewModel.showConfetti {
                ConfettiOverlayView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("参加者モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("モード選択へ") {
                    onExitRole()
                }
                .font(.subheadline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    draftName = viewModel.playerName
                    isEditingName = true
                } label: {
                    Label("名前変更", systemImage: "person.crop.circle")
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .alert("ニックネーム変更", isPresented: $isEditingName) {
            TextField("表示名を入力", text: $draftName)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                viewModel.updatePlayerName(draftName)
            }
        } message: {
            Text("リーチやビンゴになった際、司会者の画面に表示・アナウンスされる名前です。")
        }
        .alert("新しいカードに交換しますか？", isPresented: $viewModel.showRegenerateCardConfirmAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("交換する", role: .destructive) {
                viewModel.regenerateNewCard()
            }
        } message: {
            Text("現在の5×5カードが新しく作り直されます。よろしいですか？")
        }
        .alert("ゲームがリセットされました", isPresented: $viewModel.showHostResetNoticeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("司会者がゲームをリセットしたため、新しいビンゴカードが配られました。")
        }
    }

    // MARK: - Subviews

    private var connectionAndLatestNumberHeader: some View {
        let isConnected = !viewModel.syncManager.connectedPeerNames.isEmpty
        let latestNum = viewModel.latestDrawnNumber
        let latestColumn = latestNum.map { BingoColumn.column(for: $0) }

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(isConnected ? "司会者と接続中" : "司会者を探しています...")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isConnected ? Color.primary : Color.secondary)
                }

                Text("参加者名: \(viewModel.playerName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    statusBadge(
                        title: "ビンゴ",
                        count: viewModel.evaluation.bingoLineCount,
                        color: .pink
                    )
                    statusBadge(
                        title: "リーチ",
                        count: viewModel.evaluation.reachLineCount,
                        color: .orange
                    )
                }
                .padding(.top, 2)
            }

            Spacer()

            // 直近に出た番号バッジ
            VStack(spacing: 2) {
                Text("最新の出目")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let num = latestNum, let col = latestColumn {
                    HStack(spacing: 4) {
                        Text(col.rawValue)
                            .font(.subheadline.weight(.heavy))
                        Text("\(num)")
                            .font(.title2.weight(.black))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(col.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("待機中")
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func statusBadge(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
            Text("\(count)")
                .font(.caption.weight(.black))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(count > 0 ? color.opacity(0.18) : Color(uiColor: .tertiarySystemFill))
        .foregroundStyle(count > 0 ? color : Color.secondary)
        .clipShape(Capsule())
    }

    private var autoPunchToggleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $viewModel.isAutoPunch) {
                HStack(spacing: 6) {
                    Text("⚡ 自動穴あけモード")
                        .font(.subheadline.weight(.bold))
                    Text(viewModel.isAutoPunch ? "（自動オープン）" : "（手動タップ）")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.isAutoPunch ? Color.blue : Color.orange)
                }
            }
            .tint(.blue)

            Text(
                viewModel.isAutoPunch
                    ? "司会者が引いた数字のマスを自動的に開けます。"
                    : "出た数字のマスが金色に光ります。自分でタップして穴を開けましょう！"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var manualTapPromptBanner: some View {
        HStack(spacing: 8) {
            Text("🎯 タップして開ける！")
                .font(.subheadline.weight(.heavy))
            Spacer()
            Text("光っているマスが \(viewModel.highlightedCellCount) 個あります")
                .font(.caption.weight(.bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.76, blue: 0.03),
                    Color.orange
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundStyle(Color.black.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.yellow.opacity(0.45), radius: 6, y: 2)
    }

    private func celebrationBanner(text: String, isBingo: Bool) -> some View {
        HStack {
            Spacer()
            Text(text)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
            Spacer()
        }
        .background(
            isBingo
                ? LinearGradient(colors: [Color.pink, Color.purple, Color.orange], startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: (isBingo ? Color.pink : Color.orange).opacity(0.4), radius: 8, y: 4)
    }

    private var bingoCardGridSection: some View {
        VStack(spacing: 6) {
            // B・I・N・G・O 列ヘッダー
            HStack(spacing: 6) {
                ForEach(BingoColumn.allCases) { column in
                    Text(column.rawValue)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(column.color)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            // 5×5 マス目
            let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(viewModel.cardCells) { cell in
                    let colIndex = cell.id % 5
                    let column = BingoColumn.allCases[colIndex]
                    let isBingoLine = viewModel.evaluation.bingoCellIDs.contains(cell.id)
                    let isReachLine = viewModel.evaluation.reachCellIDs.contains(cell.id)

                    BingoCellButtonView(
                        cell: cell,
                        column: column,
                        isBingoLine: isBingoLine,
                        isReachLine: isReachLine,
                        pulseAnimation: pulseAnimation
                    ) {
                        viewModel.tapCell(at: cell.id)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }

    private var playerFooterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.drawnNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("これまでの出目履歴（\(viewModel.drawnNumbers.count)球）")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(viewModel.drawnNumbers.reversed().enumerated()), id: \.offset) { index, num in
                                let col = BingoColumn.column(for: num)
                                Text("\(col.rawValue)-\(num)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(index == 0 ? col.color : col.color.opacity(0.18))
                                    .foregroundStyle(index == 0 ? Color.white : col.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                viewModel.showRegenerateCardConfirmAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("新しいカードに交換する")
                        .font(.footnote.weight(.bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - 1マスのセル描画コンポーネント
private struct BingoCellButtonView: View {
    let cell: BingoCardCell
    let column: BingoColumn
    let isBingoLine: Bool
    let isReachLine: Bool
    let pulseAnimation: Bool
    let onTap: () -> Void

    private let goldColor = Color(red: 1.0, green: 0.78, blue: 0.0)

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cellBackgroundColor)

                // ゴールド太枠（手動モードの未開封ハイライト時）またはビンゴ/リーチ枠
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)

                VStack(spacing: 2) {
                    if cell.isFree {
                        Image(systemName: "star.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("フリー")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(cell.number)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(numberTextColor)

                        if cell.shouldHighlight {
                            Text("タップ!")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(goldColor)
                                .foregroundStyle(Color.black)
                                .clipShape(Capsule())
                        } else if cell.isPunched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                }
                .padding(4)
            }
            .aspectRatio(1.0, contentMode: .fit)
            // 手動タップ対象（shouldHighlight）の場合はパルス拡大縮小アニメーション
            .scaleEffect(cell.shouldHighlight ? (pulseAnimation ? 1.06 : 0.95) : 1.0)
            .shadow(
                color: cell.shouldHighlight ? goldColor.opacity(pulseAnimation ? 0.75 : 0.25) : .clear,
                radius: cell.shouldHighlight ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        // まだ出ていない数字や既に開けたマスはタップ無効化（不正防止ロック）
        .disabled(!cell.shouldHighlight)
    }

    private var cellBackgroundColor: Color {
        if cell.isPunched {
            if isBingoLine {
                return Color.pink
            }
            return column.color
        } else if cell.shouldHighlight {
            return Color.yellow.opacity(pulseAnimation ? 0.32 : 0.15)
        } else {
            return Color(uiColor: .tertiarySystemGroupedBackground)
        }
    }

    private var numberTextColor: Color {
        if cell.isPunched {
            return .white
        } else if cell.shouldHighlight {
            return .primary
        } else {
            return .primary.opacity(0.85)
        }
    }

    private var borderColor: Color {
        if cell.shouldHighlight {
            return goldColor
        } else if isBingoLine {
            return Color.yellow
        } else if isReachLine && cell.isPunched {
            return Color.orange
        } else {
            return column.color.opacity(0.25)
        }
    }

    private var borderWidth: CGFloat {
        if cell.shouldHighlight {
            return 3.5
        } else if isBingoLine {
            return 3.0
        } else if isReachLine && cell.isPunched {
            return 2.0
        } else {
            return 1.0
        }
    }
}

// MARK: - 紙吹雪エフェクト（標準SwiftUIのみで実装）
private struct ConfettiOverlayView: View {
    @State private var animate = false

    private let colors: [Color] = [.pink, .yellow, .blue, .green, .orange, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<28, id: \.self) { index in
                    let xRatio = CGFloat((index * 37) % 100) / 100.0
                    let delay = Double(index % 7) * 0.12
                    let size = CGFloat(8 + (index % 5) * 3)

                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: size, height: size)
                        .position(
                            x: geo.size.width * xRatio,
                            y: animate ? geo.size.height + 40 : -30
                        )
                        .opacity(animate ? 0.0 : 0.9)
                        .animation(
                            .easeIn(duration: 2.2)
                                .delay(delay)
                                .repeatCount(3, autoreverses: false),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
            }
        }
    }
}
