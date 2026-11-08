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
            return [
                0.04, 0.04, 0.05, 0.05, 0.05, 0.06, 0.06, 0.07,
                0.08, 0.09, 0.10, 0.11, 0.12, 0.14, 0.16, 0.18,
                0.20, 0.24, 0.28
            ]
        case .normal:
            return [
                0.04, 0.04, 0.04, 0.05, 0.05, 0.05, 0.05, 0.06,
                0.06, 0.06, 0.07, 0.07, 0.08, 0.08, 0.09, 0.10,
                0.11, 0.12, 0.13, 0.15, 0.17, 0.19, 0.22, 0.25,
                0.28, 0.32, 0.36, 0.42
            ]
        case .long:
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
            storage.saveHostDrawnNumbers(drawnNumbers)
        }
    }
    @Published private(set) var displayNumber: Int?
    @Published private(set) var isSpinning: Bool = false
    @Published var spinDurationMode: SpinDurationMode = .normal {
        didSet {
            storage.saveHostSpinDurationMode(spinDurationMode.rawValue)
        }
    }

    /// 偽司会者によるなりすましリセットや不正配信を防ぐための本物の司会者端末固有ID
    let hostID: String

    /// ゲーム回ごとの固有ID（参加者の不正なカード引き直し防止用）
    @Published private(set) var gameSessionID: String

    /// 自動保存された過去のゲーム履歴一覧
    @Published private(set) var pastGameHistory: [PastGameRecord] = []

    /// 画面上部に表示するトーストバナーメッセージ（合いの手・リーチ/ビンゴ通知）
    @Published var toastMessage: String?
    @Published var toastIsCelebration: Bool = false

    /// 参加者ごとの最新ステータス一覧（変化があるたびに自動保存）
    @Published private(set) var playerStatuses: [String: PlayerToHostPayload] = [:] {
        didSet {
            storage.saveHostPlayerStatuses(playerStatuses)
        }
    }

    /// 司会者側でロック保存する「参加者ごとの5×5カード数字配列（アプリ再インストール等による不正カード変更防止台帳）」
    @Published private(set) var registeredPlayerCards: [String: [Int]] = [:] {
        didSet {
            storage.saveHostRegisteredCards(registeredPlayerCards)
        }
    }

    /// 誤操作によるゲーム消失を防ぐための2段階確認アラートフラグ（初期選択はいずれも「いいえ」）
    @Published var showFirstResetConfirmationAlert: Bool = false
    @Published var showSecondResetConfirmationAlert: Bool = false
    @Published var showResetCompletedAlert: Bool = false

    let syncManager: BingoSyncManaging
    let speaker: BingoSpeechProviding
    private let storage: BingoStorageProviding
    private let audioPlayer: BingoAudioPlaying

    private var toastDismissTask: Task<Void, Never>?
    private var spinTask: Task<Void, Never>?

    var remainingNumbers: [Int] {
        let drawnSet = Set(drawnNumbers)
        return (1...75).filter { !drawnSet.contains($0) }
    }

    var canDrawNext: Bool {
        !isSpinning && !remainingNumbers.isEmpty
    }

    init(
        syncManager: BingoSyncManaging,
        storage: BingoStorageProviding = BingoStorage.shared,
        audioPlayer: BingoAudioPlaying = BingoSoundPlayer.shared,
        speaker: BingoSpeechProviding = BingoSpeaker.shared
    ) {
        self.syncManager = syncManager
        self.storage = storage
        self.audioPlayer = audioPlayer
        self.speaker = speaker

        self.hostID = storage.loadOrCreateHostID()
        self.gameSessionID = storage.loadOrCreateHostGameSessionID()
        let saved = storage.loadHostDrawnNumbers()
        self.drawnNumbers = saved
        self.displayNumber = saved.last
        self.playerStatuses = storage.loadHostPlayerStatuses()
        self.registeredPlayerCards = storage.loadHostRegisteredCards()
        self.pastGameHistory = storage.loadPastGameHistory()

        if let savedModeRaw = storage.loadHostSpinDurationMode(),
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
            self.handleReceivedPlayerPayload(payload)
        }
    }

    /// 参加者から受信したペイロードの検証・台帳ロック・リーチ/ビンゴ検算を実行する
    func handleReceivedPlayerPayload(_ payload: PlayerToHostPayload) {
        let playerKey = payload.playerID.isEmpty ? payload.playerName : payload.playerID
        var didDetectCardMismatch = false

        // 1. 参加者の5×5カード（25マス）を司会者側でも検証＆ロック保存（改ざん・引き直し防止）
        let lockedCardNumbers: [Int]
        if let existingLockedCard = registeredPlayerCards[playerKey] {
            lockedCardNumbers = existingLockedCard
            if payload.cardNumbers.count == 25 && existingLockedCard != payload.cardNumbers {
                BingoLogger.logWarning(
                    BingoLogger.game,
                    context: "参加者(\(payload.playerName))のカード不一致を検出したため、司会者台帳のロック済みカードで強制復元します"
                )
                didDetectCardMismatch = true
            }
        } else if BingoLogic.isValidCardNumbers(payload.cardNumbers) {
            registeredPlayerCards[playerKey] = payload.cardNumbers
            lockedCardNumbers = payload.cardNumbers
        } else {
            if !payload.cardNumbers.isEmpty {
                BingoLogger.logWarning(
                    BingoLogger.game,
                    context: "参加者(\(payload.playerName))から不正な形式のカード配列(要素数:\(payload.cardNumbers.count))を受信したため台帳登録を拒否しました"
                )
            }
            lockedCardNumbers = []
        }

        // 2. 途中参加・再接続した参加者から出目同期リクエストがあった場合、またはカード不一致時は即座に全出目とロック済みカードを送る
        if payload.requestSync || didDetectCardMismatch {
            let syncPayload = HostToPlayerPayload(
                action: .drawNumber,
                hostID: hostID,
                gameSessionID: gameSessionID,
                latestNumber: drawnNumbers.last,
                drawnNumbers: drawnNumbers,
                lockedPlayerCards: registeredPlayerCards
            )
            syncManager.sendHostPayload(syncPayload)
        }

        // 3. ゲーム進行中の名前変更ロック＆同名なりすまし防止
        let existingPlayer = playerStatuses[playerKey]
        let effectiveName = resolveEffectivePlayerName(
            incomingName: payload.playerName,
            playerKey: playerKey,
            existingPlayer: existingPlayer
        )

        // 4. 司会者側での「ビンゴ・リーチ真偽の自動検算」（不正ビンゴ申告の完全無効化）
        let previousStatus = existingPlayer?.status
        let verifiedPayload = buildVerifiedPlayerPayload(
            from: payload,
            effectiveName: effectiveName,
            lockedCardNumbers: lockedCardNumbers
        )

        playerStatuses[playerKey] = verifiedPayload

        guard previousStatus != verifiedPayload.status else { return }

        switch verifiedPayload.status {
        case .bingo:
            audioPlayer.playBingoEffect()
            showToast("🎊 \(verifiedPayload.playerName)さんがビンゴ達成です！（司会者検算OK）", isCelebration: true)
            speaker.speakPlayerStatus(playerName: verifiedPayload.playerName, status: .bingo)
        case .reach:
            audioPlayer.playReachEffect()
            showToast("🔥 おっと、\(verifiedPayload.playerName)さんがリーチになりました〜！（\(verifiedPayload.reachLineCount)ライン）", isCelebration: false)
            speaker.speakPlayerStatus(playerName: verifiedPayload.playerName, status: .reach)
        case .normal:
            break
        }
    }

    private func resolveEffectivePlayerName(
        incomingName: String,
        playerKey: String,
        existingPlayer: PlayerToHostPayload?
    ) -> String {
        let sanitizedIncoming = incomingName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = sanitizedIncoming.isEmpty ? "参加者" : sanitizedIncoming

        if let existing = existingPlayer, !drawnNumbers.isEmpty {
            // 1球目抽選開始後は登録済みの名前で固定し、途中での名前変更によるなりすましを防止する
            return existing.playerName
        }

        let otherNames = Set(
            playerStatuses
                .filter { $0.key != playerKey }
                .map { $0.value.playerName }
        )
        if otherNames.contains(fallbackName) {
            let shortSuffix = String(playerKey.prefix(4))
            return "\(fallbackName)(\(shortSuffix))"
        }
        return fallbackName
    }

    /// 司会者が実際に引いた番号集合と照合し、参加者の自己申告ステータスではなく司会者検算済みの確定ペイロードを構築する
    private func buildVerifiedPlayerPayload(
        from payload: PlayerToHostPayload,
        effectiveName: String,
        lockedCardNumbers: [Int]
    ) -> PlayerToHostPayload {
        var verifiedPayload = payload
        verifiedPayload.playerName = effectiveName
        verifiedPayload.cardNumbers = lockedCardNumbers

        guard lockedCardNumbers.count == 25 else {
            // 有効な25マスカードが未登録の間は、虚偽のビンゴ・リーチ申告が通らないよう強制的に .normal にリセットする
            verifiedPayload.status = .normal
            verifiedPayload.bingoLineCount = 0
            verifiedPayload.reachLineCount = 0
            verifiedPayload.untappedDrawnCount = 0
            verifiedPayload.theoreticalStatus = .normal
            return verifiedPayload
        }

        let verifiedCells = BingoLogic.reconstructVerifiedCells(
            cardNumbers: lockedCardNumbers,
            punchedIndices: Set(payload.punchedIndices),
            hostDrawnNumbers: drawnNumbers
        )
        let verifiedEval = BingoLogic.evaluate(cells: verifiedCells)

        let theoreticalCells = BingoLogic.reconstructTheoreticalCells(
            cardNumbers: lockedCardNumbers,
            hostDrawnNumbers: drawnNumbers
        )
        let theoreticalEval = BingoLogic.evaluate(cells: theoreticalCells)

        verifiedPayload.status = verifiedEval.status
        verifiedPayload.bingoLineCount = verifiedEval.bingoLineCount
        verifiedPayload.reachLineCount = verifiedEval.reachLineCount
        verifiedPayload.untappedDrawnCount = verifiedCells.filter { $0.shouldHighlight }.count
        verifiedPayload.theoreticalStatus = theoreticalEval.status
        return verifiedPayload
    }

    /// 抽選番号が増えた際、登録済み全参加者の理論ステータス・未タップ数を司会者側で即時再計算する
    private func reverifyAllPlayersForCurrentDrawnNumbers() {
        guard !playerStatuses.isEmpty else { return }
        var updated: [String: PlayerToHostPayload] = [:]
        for (key, player) in playerStatuses {
            let cardNums = registeredPlayerCards[key] ?? player.cardNumbers
            updated[key] = buildVerifiedPlayerPayload(
                from: player,
                effectiveName: player.playerName,
                lockedCardNumbers: cardNums
            )
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
                    self.audioPlayer.playSpinTick()
                }
                let nanoseconds = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            if Task.isCancelled { return }

            commitNextNumberDraw(from: candidates)
        }
    }

    /// ルーレット演出完了後（またはテスト時の即時抽選）に当選番号を確定し、全参加者へ配信する
    @discardableResult
    func commitNextNumberDraw(from candidates: [Int]? = nil, forcedNumber: Int? = nil) -> Int? {
        let pool = candidates ?? remainingNumbers
        let chosen: Int?
        if let forced = forcedNumber, pool.contains(forced) {
            chosen = forced
        } else {
            chosen = pool.randomElement()
        }

        guard let finalNumber = chosen else {
            isSpinning = false
            return nil
        }

        displayNumber = finalNumber
        drawnNumbers.append(finalNumber)
        isSpinning = false
        reverifyAllPlayersForCurrentDrawnNumbers()

        audioPlayer.playNumberDecided()

        let payload = HostToPlayerPayload(
            action: .drawNumber,
            hostID: hostID,
            gameSessionID: gameSessionID,
            latestNumber: finalNumber,
            drawnNumbers: drawnNumbers,
            lockedPlayerCards: registeredPlayerCards
        )
        syncManager.sendHostPayload(payload)

        if let assistMessage = speaker.speakDrawnNumber(
            finalNumber,
            totalDrawnCount: drawnNumbers.count
        ) {
            showToast("🎤 \(assistMessage)", isCelebration: false)
        }

        return finalNumber
    }

    func startReadingHistory() {
        guard !drawnNumbers.isEmpty else { return }
        speaker.speakHistory(drawnNumbers)
    }

    func stopReadingHistory() {
        speaker.stopSpeaking()
    }

    func requestResetGame() {
        showFirstResetConfirmationAlert = true
    }

    func proceedToSecondResetConfirmation() {
        showFirstResetConfirmationAlert = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            self.showSecondResetConfirmationAlert = true
        }
    }

    /// 2回目の最終確認で承認された後にリセットを実行（現在の履歴は過去ゲーム履歴へ自動保存）
    func confirmResetGame() {
        spinTask?.cancel()
        isSpinning = false
        showFirstResetConfirmationAlert = false
        showSecondResetConfirmationAlert = false
        speaker.stopSpeaking()

        if !drawnNumbers.isEmpty || !playerStatuses.isEmpty {
            storage.archiveGameHistory(
                drawnNumbers,
                players: Array(playerStatuses.values)
            )
            pastGameHistory = storage.loadPastGameHistory()
        }

        drawnNumbers.removeAll()
        displayNumber = nil
        playerStatuses.removeAll()
        registeredPlayerCards.removeAll()
        toastMessage = nil

        storage.clearHostData()
        gameSessionID = storage.regenerateHostGameSessionID()

        let resetPayload = HostToPlayerPayload(
            action: .resetGame,
            hostID: hostID,
            gameSessionID: gameSessionID,
            latestNumber: nil,
            drawnNumbers: [],
            lockedPlayerCards: [:]
        )
        syncManager.sendHostPayload(resetPayload)

        showResetCompletedAlert = true
        BingoLogger.logInfo(BingoLogger.game, message: "司会者がゲームをリセットし、新しいセッション(\(gameSessionID))を開始しました")
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
            if BingoLogic.isValidCardNumbers(player.cardNumbers) {
                restoredCards[key] = player.cardNumbers
            }
        }
        playerStatuses = restoredPlayers
        registeredPlayerCards = restoredCards
        reverifyAllPlayersForCurrentDrawnNumbers()

        let payload = HostToPlayerPayload(
            action: .drawNumber,
            hostID: hostID,
            gameSessionID: gameSessionID,
            latestNumber: drawnNumbers.last,
            drawnNumbers: drawnNumbers,
            lockedPlayerCards: registeredPlayerCards
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
