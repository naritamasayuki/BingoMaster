import Foundation
import UIKit

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published private(set) var cardCells: [BingoCardCell] = [] {
        didSet {
            storage.savePlayerCardCells(cardCells)
        }
    }
    @Published var isAutoPunch: Bool = false {
        didSet {
            storage.savePlayerIsAutoPunch(isAutoPunch)
            if isAutoPunch {
                // 途中参加後に「自動」へ切り替えた場合も、それまでの全出目番号を即座に自動で開ける
                autoPunchAllDrawnCells()
            }
        }
    }

    @Published var playerName: String
    @Published private(set) var latestDrawnNumber: Int?
    @Published private(set) var drawnNumbers: [Int] = [] {
        didSet {
            storage.savePlayerDrawnNumbers(drawnNumbers)
        }
    }
    @Published private(set) var currentGameSessionID: String?
    @Published private(set) var lockedHostID: String?
    @Published private(set) var pastGameHistory: [PastPlayerGameRecord] = []
    @Published private(set) var evaluation: BingoEvaluationResult = BingoEvaluationResult(
        status: .normal,
        bingoLineCount: 0,
        reachLineCount: 0,
        bingoCellIDs: [],
        reachCellIDs: []
    )

    /// リーチ・ビンゴ達成時の祝福オーバーレイ表示フラグ
    @Published var celebrationBannerText: String?
    @Published var showConfetti: Bool = false

    /// 司会者からリセット通知を受信した際のアラート
    @Published var showHostResetNoticeAlert: Bool = false

    /// ゲーム進行中に不正防止ロックされた操作（モード切替・名前変更）を行った際のアラート
    @Published var antiCheatAlertMessage: String?

    let playerID: String
    let syncManager: BingoSyncManaging
    private let storage: BingoStorageProviding
    private let audioPlayer: BingoAudioPlaying

    /// ゲーム進行中（1球以上抽選済み）かどうか
    var isGameInProgress: Bool {
        !drawnNumbers.isEmpty
    }

    /// 手動タップ待ち（出た数字だがまだ開けていない）のマス数
    var highlightedCellCount: Int {
        cardCells.filter { $0.shouldHighlight }.count
    }

    init(
        syncManager: BingoSyncManaging,
        storage: BingoStorageProviding = BingoStorage.shared,
        audioPlayer: BingoAudioPlaying = BingoSoundPlayer.shared
    ) {
        self.syncManager = syncManager
        self.storage = storage
        self.audioPlayer = audioPlayer

        self.playerID = storage.loadOrCreatePlayerID()
        if let savedName = storage.loadPlayerName()?.trimmingCharacters(in: .whitespacesAndNewlines),
           !savedName.isEmpty {
            self.playerName = savedName
        } else {
            self.playerName = UIDevice.current.name
        }
        self.isAutoPunch = storage.loadPlayerIsAutoPunch()
        self.currentGameSessionID = storage.loadPlayerGameSessionID()
        self.lockedHostID = storage.loadPlayerLockedHostID()
        self.pastGameHistory = storage.loadPlayerPastGameHistory()

        let savedDrawnNumbers = storage.loadPlayerDrawnNumbers()
        self.drawnNumbers = savedDrawnNumbers
        self.latestDrawnNumber = savedDrawnNumbers.last

        // アプリを落としてもカードを変えられないよう、保存済みかつ有効なカードがあれば必ず復元する
        if let savedCells = storage.loadPlayerCardCells(),
           BingoLogic.isValidCardNumbers(savedCells.map { $0.number }) {
            self.cardCells = savedCells
        } else {
            let newCells = BingoLogic.generateCard()
            self.cardCells = newCells
            storage.savePlayerCardCells(newCells)
        }

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
        // 極端に長い文字列によるUI崩れやペイロード肥大化を防ぐため最大24文字に制限する
        let safeName = String(trimmed.prefix(24))
        playerName = safeName
        storage.savePlayerName(safeName)
        sendStatusToHost(status: evaluation.status, reachCount: evaluation.reachLineCount)
    }

    private func setupSyncCallbacks() {
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

        syncManager.onReceiveHostPayload = { [weak self] payload in
            guard let self = self else { return }
            self.handleReceivedHostPayload(payload)
        }
    }

    /// 司会者から受信した出目配信・リセット通知・ロック済みカード台帳を検証して反映する
    func handleReceivedHostPayload(_ payload: HostToPlayerPayload) {
        // なりすまし司会者（2台目のスマホ等による偽ホスト）からの不正な出目配信・勝手なカードリセットを遮断
        if isGameInProgress,
           let lockedHost = lockedHostID,
           !lockedHost.isEmpty,
           !payload.hostID.isEmpty,
           lockedHost != payload.hostID {
            BingoLogger.logWarning(
                BingoLogger.game,
                context: "ロック中の司会者ID(\(lockedHost))と異なるホストID(\(payload.hostID))からのペイロードを遮断しました"
            )
            return
        }

        if !payload.hostID.isEmpty {
            lockedHostID = payload.hostID
            storage.savePlayerLockedHostID(payload.hostID)
        }

        switch payload.action {
        case .drawNumber:
            if let knownSessionID = currentGameSessionID,
               !payload.gameSessionID.isEmpty,
               knownSessionID != payload.gameSessionID,
               payload.drawnNumbers.isEmpty {
                resetCardFromHost(newSessionID: payload.gameSessionID)
                return
            }
            if !payload.gameSessionID.isEmpty {
                currentGameSessionID = payload.gameSessionID
                storage.savePlayerGameSessionID(payload.gameSessionID)
            }

            // 司会者側に登録・ロックされている自分の5×5カードがあれば照合し、万が一異なっていれば元のカードへ強制復元する
            let lockedNumbers = payload.lockedPlayerCards[playerID] ?? payload.lockedPlayerCards[playerName]
            if let lockedNumbers = lockedNumbers, BingoLogic.isValidCardNumbers(lockedNumbers) {
                let currentNumbers = cardCells.map { $0.number }
                if currentNumbers != lockedNumbers {
                    BingoLogger.logWarning(
                        BingoLogger.game,
                        context: "司会者台帳のロック済みカードとローカルカードの不一致を検出し、ロック済みカードを強制復元しました"
                    )
                    restoreLockedCard(from: lockedNumbers)
                }
            } else {
                sendStatusToHost(status: evaluation.status, reachCount: evaluation.reachLineCount)
            }

            applyHostDrawnNumbers(payload.drawnNumbers, latest: payload.latestNumber)

        case .resetGame:
            resetCardFromHost(newSessionID: payload.gameSessionID)
        }
    }

    /// 司会者側にロック保存されていた元の5×5カード数字配列からカードを強制復元（不正引き直し防止）
    private func restoreLockedCard(from numbers: [Int]) {
        guard BingoLogic.isValidCardNumbers(numbers) else { return }
        var restored: [BingoCardCell] = []
        restored.reserveCapacity(25)
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
        cardCells = restored
        storage.savePlayerCardCells(restored)
    }

    /// 司会者からの出目配列（途中参加時の全出目を含む）をカードへ反映
    func applyHostDrawnNumbers(_ numbers: [Int], latest: Int?) {
        let validNumbers = numbers.filter { (1...75).contains($0) }
        drawnNumbers = validNumbers
        latestDrawnNumber = latest ?? validNumbers.last
        storage.savePlayerDrawnNumbers(validNumbers)

        syncCardWithDrawnNumbers(validNumbers)
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

            if isAutoPunch && isNowDrawn && !cardCells[index].isPunched {
                cardCells[index].isPunched = true
                didPunchAny = true
            }
        }

        storage.savePlayerCardCells(cardCells)

        if didPunchAny {
            audioPlayer.playPunchCell()
        }

        evaluateAndNotifyIfChanged()
    }

    /// 手動タップモード時に参加者がマスをタップした際の処理
    func tapCell(at index: Int) {
        guard cardCells.indices.contains(index) else {
            BingoLogger.logWarning(BingoLogger.game, context: "範囲外のセルインデックス(\(index))へのタップを無視しました")
            return
        }
        let cell = cardCells[index]

        // 司会者がまだ引いていない数字（isDrawn == false）や既に開いているマスは開かない（不正・誤タップ防止）
        guard cell.isDrawn && !cell.isPunched && !cell.isFree else {
            return
        }

        cardCells[index].isPunched = true
        storage.savePlayerCardCells(cardCells)

        audioPlayer.playPunchCell()

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
            storage.savePlayerCardCells(cardCells)
            audioPlayer.playPunchCell()
            evaluateAndNotifyIfChanged()
        }
    }

    /// 司会者側でゲームリセットが実行された際の処理（この時のみ新しいカードが配布される＆これまでのカード履歴は自動保存される）
    private func resetCardFromHost(newSessionID: String) {
        storage.archivePlayerGameHistory(
            cardCells: cardCells,
            drawnNumbers: drawnNumbers,
            bingoLineCount: evaluation.bingoLineCount,
            reachLineCount: evaluation.reachLineCount
        )
        pastGameHistory = storage.loadPlayerPastGameHistory()

        if !newSessionID.isEmpty {
            currentGameSessionID = newSessionID
            storage.savePlayerGameSessionID(newSessionID)
        }
        drawnNumbers = []
        latestDrawnNumber = nil
        storage.savePlayerDrawnNumbers([])
        celebrationBannerText = nil
        showConfetti = false

        let freshCells = BingoLogic.generateCard()
        cardCells = freshCells
        storage.savePlayerCardCells(freshCells)
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
            audioPlayer.playBingoEffect()
            celebrationBannerText = "🎊 ビンゴ達成！（\(newEvaluation.bingoLineCount)ライン）🎊"
            showConfetti = true
        } else if didAchieveNewReach {
            audioPlayer.playReachEffect()
            celebrationBannerText = "🔥 リーチ！（\(newEvaluation.reachLineCount)ライン）🔥"
            showConfetti = false
        }

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
