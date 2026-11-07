import Foundation
import UIKit

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var cardCells: [BingoCardCell] = [] {
        didSet {
            BingoStorage.savePlayerCardCells(cardCells)
        }
    }
    @Published var isAutoPunch: Bool = false {
        didSet {
            BingoStorage.savePlayerIsAutoPunch(isAutoPunch)
            if isAutoPunch {
                // 途中参加後に「自動」へ切り替えた場合も、それまでの全出目番号を即座に自動で開ける
                autoPunchAllDrawnCells()
            }
        }
    }

    @Published var playerName: String
    @Published private(set) var latestDrawnNumber: Int? = nil
    @Published private(set) var drawnNumbers: [Int] = [] {
        didSet {
            BingoStorage.savePlayerDrawnNumbers(drawnNumbers)
        }
    }
    @Published private(set) var currentGameSessionID: String? = nil
    @Published private(set) var lockedHostID: String? = nil
    @Published private(set) var pastGameHistory: [PastPlayerGameRecord] = []
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

    /// 司会者からリセット通知を受信した際のアラート
    @Published var showHostResetNoticeAlert: Bool = false

    /// ゲーム進行中に不正防止ロックされた操作（モード切替・名前変更）を行った際のアラート
    @Published var antiCheatAlertMessage: String? = nil

    let playerID: String
    let syncManager: MultipeerSyncManager

    /// ゲーム進行中（1球以上抽選済み）かどうか
    var isGameInProgress: Bool {
        !drawnNumbers.isEmpty
    }

    /// 手動タップ待ち（出た数字だがまだ開けていない）のマス数
    var highlightedCellCount: Int {
        cardCells.filter { $0.shouldHighlight }.count
    }

    init(syncManager: MultipeerSyncManager) {
        self.syncManager = syncManager
        self.playerID = BingoStorage.loadOrCreatePlayerID()
        self.playerName = BingoStorage.loadPlayerName() ?? UIDevice.current.name
        self.isAutoPunch = BingoStorage.loadPlayerIsAutoPunch()
        self.currentGameSessionID = BingoStorage.loadPlayerGameSessionID()
        self.lockedHostID = BingoStorage.loadPlayerLockedHostID()
        self.pastGameHistory = BingoStorage.loadPlayerPastGameHistory()

        // 保存済みの出目履歴を復元
        let savedDrawnNumbers = BingoStorage.loadPlayerDrawnNumbers()
        self.drawnNumbers = savedDrawnNumbers
        self.latestDrawnNumber = savedDrawnNumbers.last

        // アプリを落としてもカードを変えられないよう、保存済みカードを必ず復元する
        if let savedCells = BingoStorage.loadPlayerCardCells() {
            self.cardCells = savedCells
        } else {
            let newCells = BingoLogic.generateCard()
            self.cardCells = newCells
            BingoStorage.savePlayerCardCells(newCells)
        }

        // 復元した出目履歴をカードに反映し、自動モードならそれまでの番号をすべて開ける
        if !savedDrawnNumbers.isEmpty {
            syncCardWithDrawnNumbers(savedDrawnNumbers)
        } else if isAutoPunch {
            autoPunchAllDrawnCells()
        }

        let eval = BingoLogic.evaluate(cells: self.cardCells)
        self.evaluation = eval
        if eval.status == .bingo {
            self.celebrationBannerText = "🎊 ビンゴ達成！（\(eval.bingoLineCount)ライン）🎊"
        } else if eval.status == .reach {
            self.celebrationBannerText = "🔥 リーチ！（\(eval.reachLineCount)ライン）🔥"
        }

        setupSyncCallbacks()
    }

    func updatePlayerName(_ newName: String) {
        guard !isGameInProgress else {
            antiCheatAlertMessage = "ゲーム開始後（1球目抽選後）は、他人へのなりすまし防止のためニックネームを変更できません。司会者がゲームをリセットした後に変更できます。"
            return
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        playerName = trimmed
        BingoStorage.savePlayerName(trimmed)
        sendStatusToHost(status: evaluation.status, reachCount: evaluation.reachLineCount)
    }

    private func setupSyncCallbacks() {
        // 途中参加・再接続時に司会者と繋がった瞬間、これまでの全出目リストを要求し、同時に自分のカードを司会者へ登録する
        syncManager.onPeerConnectedToPlayer = { [weak self] _ in
            guard let self = self else { return }
            let syncRequestPayload = PlayerToHostPayload(
                playerID: self.playerID,
                playerName: self.playerName,
                status: self.evaluation.status,
                bingoLineCount: self.evaluation.bingoLineCount,
                reachLineCount: self.evaluation.reachLineCount,
                cardNumbers: self.cardCells.map { $0.number },
                punchedIndices: self.cardCells.filter { $0.isPunched }.map { $0.id },
                requestSync: true
            )
            self.syncManager.sendPlayerPayload(syncRequestPayload)
        }

        // 司会者からの出目配信・リセット通知・ロック済みカード台帳を受信
        syncManager.onReceiveHostPayload = { [weak self] payload in
            guard let self = self else { return }

            // なりすまし司会者（2台目のスマホ等による偽ホスト）からの不正な出目配信・勝手なカードリセットを遮断
            if self.isGameInProgress,
               let lockedHost = self.lockedHostID,
               !lockedHost.isEmpty,
               !payload.hostID.isEmpty,
               lockedHost != payload.hostID {
                return
            }

            if !payload.hostID.isEmpty {
                self.lockedHostID = payload.hostID
                BingoStorage.savePlayerLockedHostID(payload.hostID)
            }

            switch payload.action {
            case .drawNumber:
                // もし本物の司会者が別セッション（リセット後の新しいゲーム）を開始していた場合のみカードをリセット
                if let knownSessionID = self.currentGameSessionID,
                   !payload.gameSessionID.isEmpty,
                   knownSessionID != payload.gameSessionID,
                   payload.drawnNumbers.isEmpty {
                    self.resetCardFromHost(newSessionID: payload.gameSessionID)
                    return
                }
                if !payload.gameSessionID.isEmpty {
                    self.currentGameSessionID = payload.gameSessionID
                    BingoStorage.savePlayerGameSessionID(payload.gameSessionID)
                }

                // 司会者側に登録・ロックされている自分の5×5カードがあれば照合し、万が一異なっていれば元のカードへ強制復元する
                let lockedNumbers = payload.lockedPlayerCards[self.playerID] ?? payload.lockedPlayerCards[self.playerName]
                if let lockedNumbers = lockedNumbers, lockedNumbers.count == 25 {
                    let currentNumbers = self.cardCells.map { $0.number }
                    if currentNumbers != lockedNumbers {
                        self.restoreLockedCard(from: lockedNumbers)
                    }
                } else {
                    // まだ司会者側に自分のカードが登録されていなければ即座に登録送信する
                    self.sendStatusToHost(status: self.evaluation.status, reachCount: self.evaluation.reachLineCount)
                }

                self.applyHostDrawnNumbers(payload.drawnNumbers, latest: payload.latestNumber)

            case .resetGame:
                self.resetCardFromHost(newSessionID: payload.gameSessionID)
            }
        }
    }

    /// 司会者側にロック保存されていた元の5×5カード数字配列からカードを強制復元（不正引き直し防止）
    private func restoreLockedCard(from numbers: [Int]) {
        guard numbers.count == 25 else { return }
        var restored: [BingoCardCell] = []
        for (index, num) in numbers.enumerated() {
            let isFree = (index == 12 || num == 0)
            let previouslyPunched = cardCells.first(where: { $0.number == num })?.isPunched ?? false
            restored.append(
                BingoCardCell(
                    id: index,
                    number: isFree ? 0 : num,
                    isFree: isFree,
                    isDrawn: isFree,
                    isPunched: isFree || previouslyPunched
                )
            )
        }
        self.cardCells = restored
        BingoStorage.savePlayerCardCells(restored)
    }

    /// 司会者からの出目配列（途中参加時の全出目を含む）をカードへ反映
    func applyHostDrawnNumbers(_ numbers: [Int], latest: Int?) {
        self.drawnNumbers = numbers
        self.latestDrawnNumber = latest ?? numbers.last
        BingoStorage.savePlayerDrawnNumbers(numbers)

        syncCardWithDrawnNumbers(numbers)
    }

    /// これまでの出目配列とカードの25マスを照合し、自動モード時は該当番号をすべて自動で開ける
    private func syncCardWithDrawnNumbers(_ numbers: [Int]) {
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

            // 自動穴あけモードがONなら、これまでに出た番号もすべて自動で開ける
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

    /// 途中参加後などに「⚡ 自動穴あけモード」をONに切り替えた瞬間、すでに出ている番号のマスを一括で自動オープンする
    private func autoPunchAllDrawnCells() {
        let drawnSet = Set(drawnNumbers)
        var didPunch = false

        for index in cardCells.indices {
            if cardCells[index].isFree { continue }
            if drawnSet.contains(cardCells[index].number) {
                cardCells[index].isDrawn = true
            }
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

    /// 司会者側でゲームリセットが実行された際の処理（この時のみ新しいカードが配布される＆これまでのカード履歴は自動保存される）
    private func resetCardFromHost(newSessionID: String) {
        // リセット前のカード＆出目履歴を自動アーカイブ保存
        BingoStorage.archivePlayerGameHistory(
            cardCells: cardCells,
            drawnNumbers: drawnNumbers,
            bingoLineCount: evaluation.bingoLineCount,
            reachLineCount: evaluation.reachLineCount
        )
        pastGameHistory = BingoStorage.loadPlayerPastGameHistory()

        if !newSessionID.isEmpty {
            currentGameSessionID = newSessionID
            BingoStorage.savePlayerGameSessionID(newSessionID)
        }
        drawnNumbers = []
        latestDrawnNumber = nil
        BingoStorage.savePlayerDrawnNumbers([])
        celebrationBannerText = nil
        showConfetti = false

        let freshCells = BingoLogic.generateCard()
        cardCells = freshCells
        BingoStorage.savePlayerCardCells(freshCells)
        evaluation = BingoLogic.evaluate(cells: freshCells)
        sendStatusToHost(status: .normal, reachCount: 0)
        showHostResetNoticeAlert = true
    }

    /// 縦横斜め12ラインを走査し、新規リーチまたはビンゴ達成時にエフェクト表示＆司会者へ最新カード穴あけ状態を送信
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
        } else if didAchieveNewReach {
            BingoSoundPlayer.shared.playReachEffect()
            celebrationBannerText = "🔥 リーチ！（\(newEvaluation.reachLineCount)ライン）🔥"
            showConfetti = false
        }

        // 司会者側でのリアルタイム検算・カード確認シート用に、現在の穴あけ状態を毎回同期送信
        sendStatusToHost(status: newEvaluation.status, reachCount: newEvaluation.reachLineCount)
    }

    private func sendStatusToHost(status: PlayerToHostPayload.PlayerStatus, reachCount: Int) {
        let payload = PlayerToHostPayload(
            playerID: playerID,
            playerName: playerName,
            status: status,
            bingoLineCount: evaluation.bingoLineCount,
            reachLineCount: reachCount,
            cardNumbers: cardCells.map { $0.number },
            punchedIndices: cardCells.filter { $0.isPunched }.map { $0.id },
            requestSync: false
        )
        syncManager.sendPlayerPayload(payload)
    }
}
