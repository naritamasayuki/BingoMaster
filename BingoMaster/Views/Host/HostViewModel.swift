import Combine
import Foundation
import MultipeerConnectivity

enum SpinDurationMode: String, CaseIterable, Identifiable {
    case short = "short"
    case normal = "normal"
    case long = "long"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short: return "短め"
        case .normal: return "普通"
        case .long: return "長い"
        }
    }

    var descriptionText: String {
        switch self {
        case .short: return "約2.2秒（サクサク進行）"
        case .normal: return "約4.0秒（標準の減速演出）"
        case .long: return "約6.5秒（ドキドキじらし演出）"
        }
    }

    /// モードごとのルーレット減速インターバル配列
    var intervals: [TimeInterval] {
        switch self {
        case .short:
            // 約 2.2秒
            return [
                0.04, 0.04, 0.05, 0.05, 0.05, 0.06, 0.06, 0.07,
                0.08, 0.09, 0.10, 0.11, 0.12, 0.14, 0.16, 0.18,
                0.20, 0.24, 0.28
            ]
        case .normal:
            // 約 4.0秒
            return [
                0.04, 0.04, 0.04, 0.05, 0.05, 0.05, 0.05, 0.06,
                0.06, 0.06, 0.07, 0.07, 0.08, 0.08, 0.09, 0.10,
                0.11, 0.12, 0.13, 0.15, 0.17, 0.19, 0.22, 0.25,
                0.28, 0.32, 0.36, 0.42
            ]
        case .long:
            // 約 6.5秒（終盤にゆっくりじらすクライマックス演出）
            return [
                0.04, 0.04, 0.04, 0.04, 0.05, 0.05, 0.05, 0.05,
                0.06, 0.06, 0.06, 0.06, 0.07, 0.07, 0.08, 0.08,
                0.09, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.16,
                0.18, 0.20, 0.22, 0.25, 0.28, 0.32, 0.36, 0.40,
                0.45, 0.50, 0.55, 0.65
            ]
        }
    }
}

@MainActor
final class HostViewModel: ObservableObject {
    @Published private(set) var drawnNumbers: [Int] = [] {
        didSet {
            BingoStorage.saveHostDrawnNumbers(drawnNumbers)
        }
    }
    @Published private(set) var displayNumber: Int? = nil
    @Published private(set) var isSpinning: Bool = false
    @Published var spinDurationMode: SpinDurationMode = .normal {
        didSet {
            BingoStorage.saveHostSpinDurationMode(spinDurationMode.rawValue)
        }
    }

    /// 本物の司会者端末固有ID（偽ホストによる不正防止用）
    let hostID: String

    /// 現在のゲームセッション固有ID（参加者の不正カード引き直し防止用）
    @Published private(set) var gameSessionID: String

    /// 自動保存された過去のゲーム履歴一覧
    @Published private(set) var pastGameHistory: [PastGameRecord] = []

    /// 画面上部に表示するトーストバナーメッセージ（合いの手・リーチ/ビンゴ通知）
    @Published var toastMessage: String? = nil
    @Published var toastIsCelebration: Bool = false

    /// 参加者ごとの最新ステータス一覧（変化があるたびに自動保存）
    @Published private(set) var playerStatuses: [String: PlayerToHostPayload] = [:] {
        didSet {
            BingoStorage.saveHostPlayerStatuses(playerStatuses)
        }
    }

    /// 司会者側でロック保存する「参加者ごとの5×5カード数字配列（アプリを落としての不正カード変更防止台帳）」
    @Published private(set) var registeredPlayerCards: [String: [Int]] = [:] {
        didSet {
            BingoStorage.saveHostRegisteredCards(registeredPlayerCards)
        }
    }

    /// 2回確認リセット用アラートフラグ（1回目確認 ➔ 2回目最終確認 ➔ 完了通知）
    @Published var showFirstResetConfirmationAlert: Bool = false
    @Published var showSecondResetConfirmationAlert: Bool = false
    @Published var showResetCompletedAlert: Bool = false

    let syncManager: MultipeerSyncManager
    let speaker = BingoSpeaker.shared

    private var toastDismissTask: Task<Void, Never>?
    private var spinTask: Task<Void, Never>?

    var remainingNumbers: [Int] {
        let drawnSet = Set(drawnNumbers)
        return (1...75).filter { !drawnSet.contains($0) }
    }

    var canDrawNext: Bool {
        !isSpinning && !remainingNumbers.isEmpty
    }

    init(syncManager: MultipeerSyncManager) {
        self.syncManager = syncManager
        self.hostID = BingoStorage.loadOrCreateHostID()
        self.gameSessionID = BingoStorage.loadOrCreateHostGameSessionID()
        let saved = BingoStorage.loadHostDrawnNumbers()
        self.drawnNumbers = saved
        self.displayNumber = saved.last
        self.playerStatuses = BingoStorage.loadHostPlayerStatuses()
        self.registeredPlayerCards = BingoStorage.loadHostRegisteredCards()
        self.pastGameHistory = BingoStorage.loadPastGameHistory()

        if let savedModeRaw = BingoStorage.loadHostSpinDurationMode(),
           let savedMode = SpinDurationMode(rawValue: savedModeRaw) {
            self.spinDurationMode = savedMode
        }

        setupSyncCallbacks()
        reverifyAllPlayersForCurrentDrawnNumbers()
    }

    private func setupSyncCallbacks() {
        // 新規または再接続した参加者に現在の全出目リストとロック済みカード台帳を即時送信
        syncManager.onPeerConnectedToHost = { [weak self] peerID in
            guard let self = self else { return }
            let payload = HostToPlayerPayload(
                action: .drawNumber,
                hostID: self.hostID,
                gameSessionID: self.gameSessionID,
                latestNumber: self.drawnNumbers.last,
                drawnNumbers: self.drawnNumbers,
                lockedPlayerCards: self.registeredPlayerCards
            )
            self.syncManager.sendHostPayload(payload, to: [peerID])
        }

        // 参加者からのリーチ・ビンゴ通知または途中参加時の全出目リクエスト・カード登録を受信
        syncManager.onReceivePlayerPayload = { [weak self] payload in
            guard let self = self else { return }

            let playerKey = payload.playerID.isEmpty ? payload.playerName : payload.playerID
            var didDetectCardMismatch = false

            // 1. 参加者の5×5カード（25マス）を司会者側でも検証＆ロック保存（改ざん・引き直し防止）
            let lockedCardNumbers: [Int]
            if let existingLockedCard = self.registeredPlayerCards[playerKey] {
                lockedCardNumbers = existingLockedCard
                if payload.cardNumbers.count == 25 && existingLockedCard != payload.cardNumbers {
                    // 万が一異なるカードで再接続してきた場合は、司会者側に保存された元のカードを強制送還する
                    didDetectCardMismatch = true
                }
            } else if BingoLogic.isValidCardNumbers(payload.cardNumbers) {
                self.registeredPlayerCards[playerKey] = payload.cardNumbers
                lockedCardNumbers = payload.cardNumbers
            } else {
                lockedCardNumbers = payload.cardNumbers
            }

            // 2. 途中参加・再接続した参加者から出目同期リクエストがあった場合、またはカード不一致時は即座に全出目とロック済みカードを送る
            if payload.requestSync || didDetectCardMismatch {
                let syncPayload = HostToPlayerPayload(
                    action: .drawNumber,
                    hostID: self.hostID,
                    gameSessionID: self.gameSessionID,
                    latestNumber: self.drawnNumbers.last,
                    drawnNumbers: self.drawnNumbers,
                    lockedPlayerCards: self.registeredPlayerCards
                )
                self.syncManager.sendHostPayload(syncPayload)
            }

            // 3. ゲーム進行中の名前変更ロック＆同名なりすまし防止
            let existingPlayer = self.playerStatuses[playerKey]
            var effectiveName: String
            if let existing = existingPlayer, !self.drawnNumbers.isEmpty {
                // 抽選開始後は登録済みの名前で固定（途中での名前変更なりすまし防止）
                effectiveName = existing.playerName
            } else {
                effectiveName = payload.playerName
                // 他の参加者（別playerKey）と同名の場合は識別番号を付与してなりすましを防止
                let otherNames = Set(
                    self.playerStatuses
                        .filter { $0.key != playerKey }
                        .map { $0.value.playerName }
                )
                if otherNames.contains(effectiveName) {
                    let shortSuffix = String(playerKey.prefix(4))
                    effectiveName = "\(effectiveName)(\(shortSuffix))"
                }
            }

            // 4. 司会者側での「ビンゴ・リーチ真偽の自動検算」（不正ビンゴ申告の完全無効化）
            let previousStatus = existingPlayer?.status
            var verifiedPayload = payload
            verifiedPayload.playerName = effectiveName
            verifiedPayload.cardNumbers = lockedCardNumbers

            if lockedCardNumbers.count == 25 {
                let verifiedCells = BingoLogic.reconstructVerifiedCells(
                    cardNumbers: lockedCardNumbers,
                    punchedIndices: Set(payload.punchedIndices),
                    hostDrawnNumbers: self.drawnNumbers
                )
                let verifiedEval = BingoLogic.evaluate(cells: verifiedCells)

                let theoreticalCells = BingoLogic.reconstructTheoreticalCells(
                    cardNumbers: lockedCardNumbers,
                    hostDrawnNumbers: self.drawnNumbers
                )
                let theoreticalEval = BingoLogic.evaluate(cells: theoreticalCells)

                verifiedPayload.status = verifiedEval.status
                verifiedPayload.bingoLineCount = verifiedEval.bingoLineCount
                verifiedPayload.reachLineCount = verifiedEval.reachLineCount
                verifiedPayload.untappedDrawnCount = verifiedCells.filter { $0.shouldHighlight }.count
                verifiedPayload.theoreticalStatus = theoreticalEval.status
            }

            self.playerStatuses[playerKey] = verifiedPayload

            guard previousStatus != verifiedPayload.status else { return }

            switch verifiedPayload.status {
            case .bingo:
                BingoSoundPlayer.shared.playBingoEffect()
                self.showToast("🎊 \(verifiedPayload.playerName)さんがビンゴ達成です！（司会者検算OK）", isCelebration: true)
                self.speaker.speakPlayerStatus(playerName: verifiedPayload.playerName, status: .bingo)
            case .reach:
                BingoSoundPlayer.shared.playReachEffect()
                self.showToast("🔥 おっと、\(verifiedPayload.playerName)さんがリーチになりました〜！（\(verifiedPayload.reachLineCount)ライン）", isCelebration: false)
                self.speaker.speakPlayerStatus(playerName: verifiedPayload.playerName, status: .reach)
            case .normal:
                break
            }
        }
    }

    /// 抽選番号が増えた際、登録済み全参加者の理論ステータス・未タップ数を司会者側で即時再計算する
    private func reverifyAllPlayersForCurrentDrawnNumbers() {
        guard !playerStatuses.isEmpty else { return }
        var updated = playerStatuses
        for (key, var player) in updated {
            let cardNums = registeredPlayerCards[key] ?? player.cardNumbers
            guard cardNums.count == 25 else { continue }
            player.cardNumbers = cardNums

            let verifiedCells = BingoLogic.reconstructVerifiedCells(
                cardNumbers: cardNums,
                punchedIndices: Set(player.punchedIndices),
                hostDrawnNumbers: drawnNumbers
            )
            let verifiedEval = BingoLogic.evaluate(cells: verifiedCells)

            let theoreticalCells = BingoLogic.reconstructTheoreticalCells(
                cardNumbers: cardNums,
                hostDrawnNumbers: drawnNumbers
            )
            let theoreticalEval = BingoLogic.evaluate(cells: theoreticalCells)

            player.status = verifiedEval.status
            player.bingoLineCount = verifiedEval.bingoLineCount
            player.reachLineCount = verifiedEval.reachLineCount
            player.untappedDrawnCount = verifiedCells.filter { $0.shouldHighlight }.count
            player.theoreticalStatus = theoreticalEval.status
            updated[key] = player
        }
        playerStatuses = updated
    }

    /// 次の数字を抽選する（選択した長さのルーレット減速演出つき）
    func drawNextNumber() {
        let candidates = remainingNumbers
        guard !isSpinning, !candidates.isEmpty else { return }

        isSpinning = true
        speaker.stopSpeaking()

        let intervals = spinDurationMode.intervals

        spinTask?.cancel()
        spinTask = Task { @MainActor in
            for interval in intervals {
                if Task.isCancelled { return }
                if let randomCandidate = candidates.randomElement() {
                    self.displayNumber = randomCandidate
                    BingoSoundPlayer.shared.playSpinTick()
                }
                let nanoseconds = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            if Task.isCancelled { return }

            // 最終的な当選番号を確定
            guard let finalNumber = candidates.randomElement() else {
                self.isSpinning = false
                return
            }

            self.displayNumber = finalNumber
            self.drawnNumbers.append(finalNumber) // didSet で即座に自動保存される
            self.isSpinning = false
            self.reverifyAllPlayersForCurrentDrawnNumbers()

            // 決定チャイム音と振動
            BingoSoundPlayer.shared.playNumberDecided()

            // 全参加者にブロードキャスト配信
            let payload = HostToPlayerPayload(
                action: .drawNumber,
                hostID: self.hostID,
                gameSessionID: self.gameSessionID,
                latestNumber: finalNumber,
                drawnNumbers: self.drawnNumbers,
                lockedPlayerCards: self.registeredPlayerCards
            )
            self.syncManager.sendHostPayload(payload)

            // 日本語音声で2回繰り返し読み上げ + 40%確率の合いの手
            if let assistMessage = self.speaker.speakDrawnNumber(
                finalNumber,
                totalDrawnCount: self.drawnNumbers.count
            ) {
                self.showToast("🎤 \(assistMessage)", isCelebration: false)
            }
        }
    }

    /// 履歴をゆっくり一括読み上げ
    func startReadingHistory() {
        guard !drawnNumbers.isEmpty else { return }
        speaker.speakHistory(drawnNumbers)
    }

    /// 音声読み上げを停止
    func stopReadingHistory() {
        speaker.stopSpeaking()
    }

    /// リセットボタン押下時（1回目の確認を表示）
    func requestResetGame() {
        showFirstResetConfirmationAlert = true
    }

    /// 1回目の確認で「はい」が押された時（2回目の最終確認を表示）
    func proceedToSecondResetConfirmation() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.showSecondResetConfirmationAlert = true
        }
    }

    /// 2回目の最終確認で承認された後にリセットを実行（現在の履歴は過去ゲーム履歴へ自動保存）
    func confirmResetGame() {
        spinTask?.cancel()
        isSpinning = false
        speaker.stopSpeaking()

        // リセット前のゲーム履歴（出目＋参加者一覧）を自動アーカイブ保存
        if !drawnNumbers.isEmpty || !playerStatuses.isEmpty {
            BingoStorage.archiveGameHistory(
                drawnNumbers,
                players: Array(playerStatuses.values)
            )
            pastGameHistory = BingoStorage.loadPastGameHistory()
        }

        drawnNumbers.removeAll()
        displayNumber = nil
        playerStatuses.removeAll()
        registeredPlayerCards.removeAll()
        toastMessage = nil

        BingoStorage.clearHostData()
        self.gameSessionID = BingoStorage.regenerateHostGameSessionID()

        let resetPayload = HostToPlayerPayload(
            action: .resetGame,
            hostID: self.hostID,
            gameSessionID: self.gameSessionID,
            latestNumber: nil,
            drawnNumbers: [],
            lockedPlayerCards: [:]
        )
        syncManager.sendHostPayload(resetPayload)

        showResetCompletedAlert = true
    }

    /// 過去の自動保存されたゲーム履歴（出目・参加者状態）から状態を復元する
    func restoreFromPastRecord(_ record: PastGameRecord) {
        guard !isSpinning else { return }
        speaker.stopSpeaking()

        drawnNumbers = record.drawnNumbers
        displayNumber = record.drawnNumbers.last

        var restoredPlayers: [String: PlayerToHostPayload] = [:]
        var restoredCards: [String: [Int]] = [:]
        for player in record.players {
            let key = player.playerID.isEmpty ? player.playerName : player.playerID
            restoredPlayers[key] = player
            if player.cardNumbers.count == 25 {
                restoredCards[key] = player.cardNumbers
            }
        }
        playerStatuses = restoredPlayers
        registeredPlayerCards = restoredCards
        reverifyAllPlayersForCurrentDrawnNumbers()

        let payload = HostToPlayerPayload(
            action: .drawNumber,
            hostID: self.hostID,
            gameSessionID: self.gameSessionID,
            latestNumber: self.drawnNumbers.last,
            drawnNumbers: self.drawnNumbers,
            lockedPlayerCards: self.registeredPlayerCards
        )
        syncManager.sendHostPayload(payload)
        showToast("📂 \(record.formattedDate) のゲーム履歴（\(record.drawnNumbers.count)球・参加者\(record.players.count)人）を復元しました", isCelebration: false)
    }

    private func showToast(_ text: String, isCelebration: Bool) {
        toastDismissTask?.cancel()
        toastIsCelebration = isCelebration
        toastMessage = text

        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                self.toastMessage = nil
            }
        }
    }
}
