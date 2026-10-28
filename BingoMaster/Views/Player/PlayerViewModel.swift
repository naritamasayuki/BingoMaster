import Foundation
import UIKit

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var cardCells: [BingoCardCell] = []
    @Published var isAutoPunch: Bool = false {
        didSet {
            BingoStorage.savePlayerIsAutoPunch(isAutoPunch)
            if isAutoPunch {
                autoPunchAllDrawnCells()
            }
        }
    }

    @Published var playerName: String
    @Published private(set) var latestDrawnNumber: Int? = nil
    @Published private(set) var drawnNumbers: [Int] = []
    @Published private(set) var evaluation: BingoEvaluationResult = BingoEvaluationResult(
        status: .normal,
        bingoLineCount: 0,
        reachLineCount: 0,
        bingoCellIDs: [],
        reachCellIDs: []
    )

    /// リーチ・ビンゴ達成時の祝福オーバーレイ表示フラグ
    @Published var celebrationBannerText: String? = nil
    @Published var showConfetti: Bool = false

    /// カード再生成確認アラート（ゲーム開始前やリセット時用）
    @Published var showRegenerateCardConfirmAlert: Bool = false
    /// 司会者からリセット通知を受信した際のアラート
    @Published var showHostResetNoticeAlert: Bool = false

    let syncManager: MultipeerSyncManager

    /// 手動タップ待ち（出た数字だがまだ開けていない）のマス数
    var highlightedCellCount: Int {
        cardCells.filter { $0.shouldHighlight }.count
    }

    init(syncManager: MultipeerSyncManager) {
        self.syncManager = syncManager
        self.playerName = BingoStorage.loadPlayerName() ?? UIDevice.current.name
        self.isAutoPunch = BingoStorage.loadPlayerIsAutoPunch()

        if let savedCells = BingoStorage.loadPlayerCardCells() {
            self.cardCells = savedCells
        } else {
            let newCells = BingoLogic.generateCard()
            self.cardCells = newCells
            BingoStorage.savePlayerCardCells(newCells)
        }

        self.evaluation = BingoLogic.evaluate(cells: self.cardCells)
        setupSyncCallbacks()

        if isAutoPunch {
            autoPunchAllDrawnCells()
        }
    }

    func updatePlayerName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playerName = trimmed
        BingoStorage.savePlayerName(trimmed)
    }

    private func setupSyncCallbacks() {
        syncManager.onReceiveHostPayload = { [weak self] payload in
            guard let self = self else { return }
            switch payload.action {
            case .drawNumber:
                self.applyHostDrawnNumbers(payload.drawnNumbers, latest: payload.latestNumber)
            case .resetGame:
                self.resetCardFromHost()
            }
        }
    }

    /// 司会者からの出目配列をカードへ反映
    func applyHostDrawnNumbers(_ numbers: [Int], latest: Int?) {
        self.drawnNumbers = numbers
        self.latestDrawnNumber = latest ?? numbers.last

        let drawnSet = Set(numbers)
        var didPunchAny = false

        for index in cardCells.indices {
            if cardCells[index].isFree {
                cardCells[index].isDrawn = true
                cardCells[index].isPunched = true
                continue
            }

            let isNowDrawn = drawnSet.contains(cardCells[index].number)
            cardCells[index].isDrawn = isNowDrawn

            if isAutoPunch && isNowDrawn && !cardCells[index].isPunched {
                cardCells[index].isPunched = true
                didPunchAny = true
            }
        }

        BingoStorage.savePlayerCardCells(cardCells)

        if didPunchAny {
            BingoSoundPlayer.shared.playPunchCell()
        }

        evaluateAndNotifyIfChanged()
    }

    /// 手動タップモード時に参加者がマスをタップした際の処理
    func tapCell(at index: Int) {
        guard cardCells.indices.contains(index) else { return }
        let cell = cardCells[index]

        // 司会者がまだ引いていない数字（isDrawn == false）や既に開いているマスは開かない（不正・誤タップ防止）
        guard cell.isDrawn && !cell.isPunched && !cell.isFree else {
            return
        }

        cardCells[index].isPunched = true
        BingoStorage.savePlayerCardCells(cardCells)

        // 小気味よいスタンプ音と強い振動 (.heavy)
        BingoSoundPlayer.shared.playPunchCell()

        evaluateAndNotifyIfChanged()
    }

    /// 自動穴あけモードに切り替えた瞬間、すでに出ている未開封マスを一括で開ける
    private func autoPunchAllDrawnCells() {
        var didPunch = false
        for index in cardCells.indices {
            if cardCells[index].isDrawn && !cardCells[index].isPunched {
                cardCells[index].isPunched = true
                didPunch = true
            }
        }
        if didPunch {
            BingoStorage.savePlayerCardCells(cardCells)
            BingoSoundPlayer.shared.playPunchCell()
            evaluateAndNotifyIfChanged()
        }
    }

    /// 新しいビンゴカードを作り直す（現在の出目状況は維持）
    func regenerateNewCard() {
        var newCells = BingoLogic.generateCard()
        let drawnSet = Set(drawnNumbers)

        for index in newCells.indices where !newCells[index].isFree {
            let isDrawn = drawnSet.contains(newCells[index].number)
            newCells[index].isDrawn = isDrawn
            if isAutoPunch && isDrawn {
                newCells[index].isPunched = true
            }
        }

        cardCells = newCells
        BingoStorage.savePlayerCardCells(newCells)
        celebrationBannerText = nil
        showConfetti = false
        evaluation = BingoLogic.evaluate(cells: newCells)
    }

    /// 司会者側でゲームリセットが実行された際の処理
    private func resetCardFromHost() {
        drawnNumbers = []
        latestDrawnNumber = nil
        celebrationBannerText = nil
        showConfetti = false

        let freshCells = BingoLogic.generateCard()
        cardCells = freshCells
        BingoStorage.savePlayerCardCells(freshCells)
        evaluation = BingoLogic.evaluate(cells: freshCells)
        showHostResetNoticeAlert = true
    }

    /// 縦横斜め12ラインを走査し、新規リーチまたはビンゴ達成時にエフェクト表示＆司会者へ送信
    private func evaluateAndNotifyIfChanged() {
        let oldEvaluation = evaluation
        let newEvaluation = BingoLogic.evaluate(cells: cardCells)
        evaluation = newEvaluation

        let didAchieveNewBingo = newEvaluation.bingoLineCount > oldEvaluation.bingoLineCount
        let didAchieveNewReach = newEvaluation.status == .reach && newEvaluation.reachLineCount > oldEvaluation.reachLineCount

        if didAchieveNewBingo {
            BingoSoundPlayer.shared.playBingoEffect()
            celebrationBannerText = "🎊 ビンゴ達成！（\(newEvaluation.bingoLineCount)ライン）🎊"
            showConfetti = true
            sendStatusToHost(status: .bingo, reachCount: newEvaluation.reachLineCount)
        } else if didAchieveNewReach {
            BingoSoundPlayer.shared.playReachEffect()
            celebrationBannerText = "🔥 リーチ！（\(newEvaluation.reachLineCount)ライン）🔥"
            showConfetti = false
            sendStatusToHost(status: .reach, reachCount: newEvaluation.reachLineCount)
        } else if oldEvaluation.status != newEvaluation.status {
            sendStatusToHost(status: newEvaluation.status, reachCount: newEvaluation.reachLineCount)
        }
    }

    private func sendStatusToHost(status: PlayerToHostPayload.PlayerStatus, reachCount: Int) {
        let payload = PlayerToHostPayload(
            playerName: playerName,
            status: status,
            reachLineCount: reachCount
        )
        syncManager.sendPlayerPayload(payload)
    }
}
