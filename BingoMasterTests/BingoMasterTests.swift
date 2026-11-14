import MultipeerConnectivity
import XCTest
@testable import BingoMaster

// MARK: - In-Memory Test Doubles (実機ストレージやスピーカーに依存しない高速ユニットテスト用モック)

final class InMemoryBingoStorage: BingoStorageProviding {
    var activeRole: String?
    var hostID: String = "test-host-id-0001"
    var hostGameSessionID: String = "session-0001"
    var hostDrawnNumbers: [Int] = []
    var hostPlayerStatuses: [String: PlayerToHostPayload] = [:]
    var hostRegisteredCards: [String: [Int]] = [:]
    var hostSpinDurationMode: String?
    var pastGameHistory: [PastGameRecord] = []

    var playerID: String = "test-player-id-0001"
    var playerCardCells: [BingoCardCell]?
    var playerIsAutoPunch: Bool = false
    var playerName: String? = "テスト太郎"
    var playerLockedHostID: String?
    var playerGameSessionID: String?
    var playerDrawnNumbers: [Int] = []
    var playerPastGameHistory: [PastPlayerGameRecord] = []

    func saveActiveRole(_ role: String) { activeRole = role }
    func loadActiveRole() -> String? { activeRole }

    func saveHostDrawnNumbers(_ numbers: [Int]) { hostDrawnNumbers = numbers }
    func loadHostDrawnNumbers() -> [Int] { hostDrawnNumbers }
    func saveHostPlayerStatuses(_ statuses: [String: PlayerToHostPayload]) { hostPlayerStatuses = statuses }
    func loadHostPlayerStatuses() -> [String: PlayerToHostPayload] { hostPlayerStatuses }
    func saveHostRegisteredCards(_ cards: [String: [Int]]) { hostRegisteredCards = cards }
    func loadHostRegisteredCards() -> [String: [Int]] { hostRegisteredCards }
    func clearHostData() {
        hostDrawnNumbers = []
        hostPlayerStatuses = [:]
        hostRegisteredCards = [:]
    }
    func loadOrCreateHostID() -> String { hostID }
    func loadOrCreateHostGameSessionID() -> String { hostGameSessionID }
    @discardableResult
    func regenerateHostGameSessionID() -> String {
        hostGameSessionID = "session-\(UUID().uuidString.prefix(8))"
        return hostGameSessionID
    }
    func saveHostSpinDurationMode(_ rawValue: String) { hostSpinDurationMode = rawValue }
    func loadHostSpinDurationMode() -> String? { hostSpinDurationMode }
    func archiveGameHistory(_ drawnNumbers: [Int], players: [PlayerToHostPayload]) {
        guard !drawnNumbers.isEmpty || !players.isEmpty else { return }
        pastGameHistory.insert(
            PastGameRecord(drawnNumbers: drawnNumbers, players: players),
            at: 0
        )
    }
    func loadPastGameHistory() -> [PastGameRecord] { pastGameHistory }

    func loadOrCreatePlayerID() -> String { playerID }
    func savePlayerCardCells(_ cells: [BingoCardCell]) { playerCardCells = cells }
    func loadPlayerCardCells() -> [BingoCardCell]? { playerCardCells }
    func savePlayerIsAutoPunch(_ isAutoPunch: Bool) { playerIsAutoPunch = isAutoPunch }
    func loadPlayerIsAutoPunch() -> Bool { playerIsAutoPunch }
    func savePlayerName(_ name: String) { playerName = name }
    func loadPlayerName() -> String? { playerName }
    func clearPlayerCardCells() {
        playerCardCells = nil
        playerDrawnNumbers = []
    }
    func savePlayerLockedHostID(_ hostID: String) { playerLockedHostID = hostID }
    func loadPlayerLockedHostID() -> String? { playerLockedHostID }
    func clearPlayerLockedHostID() { playerLockedHostID = nil }
    func savePlayerGameSessionID(_ sessionID: String) { playerGameSessionID = sessionID }
    func loadPlayerGameSessionID() -> String? { playerGameSessionID }
    func savePlayerDrawnNumbers(_ numbers: [Int]) { playerDrawnNumbers = numbers }
    func loadPlayerDrawnNumbers() -> [Int] { playerDrawnNumbers }
    func archivePlayerGameHistory(
        cardCells: [BingoCardCell],
        drawnNumbers: [Int],
        bingoLineCount: Int,
        reachLineCount: Int
    ) {
        let punchedCount = cardCells.filter { !$0.isFree && $0.isPunched }.count
        guard !drawnNumbers.isEmpty || punchedCount > 0 else { return }
        playerPastGameHistory.insert(
            PastPlayerGameRecord(
                id: UUID(),
                savedAt: Date(),
                cardCells: cardCells,
                drawnNumbers: drawnNumbers,
                bingoLineCount: bingoLineCount,
                reachLineCount: reachLineCount
            ),
            at: 0
        )
    }
    func loadPlayerPastGameHistory() -> [PastPlayerGameRecord] { playerPastGameHistory }
}

@MainActor
final class MockBingoSyncManager: BingoSyncManaging {
    var connectedPeerNames: [String] = []
    var isActive: Bool = false

    var onPeerConnectedToHost: ((MCPeerID) -> Void)?
    var onPeerConnectedToPlayer: ((MCPeerID) -> Void)?
    var onReceivePlayerPayload: ((PlayerToHostPayload) -> Void)?
    var onReceiveHostPayload: ((HostToPlayerPayload) -> Void)?

    private(set) var sentHostPayloads: [HostToPlayerPayload] = []
    private(set) var sentPlayerPayloads: [PlayerToHostPayload] = []

    func startHosting() { isActive = true }
    func startBrowsing() { isActive = true }
    func stop() { isActive = false }

    func sendHostPayload(_ payload: HostToPlayerPayload, to targetPeers: [MCPeerID]?) {
        sentHostPayloads.append(payload)
    }

    func sendPlayerPayload(_ payload: PlayerToHostPayload) {
        sentPlayerPayloads.append(payload)
    }
}

@MainActor
final class MockBingoAudioPlayer: BingoAudioPlaying {
    private(set) var spinTickCount = 0
    private(set) var numberDecidedCount = 0
    private(set) var punchCellCount = 0
    private(set) var reachEffectCount = 0
    private(set) var bingoEffectCount = 0

    func playSpinTick() { spinTickCount += 1 }
    func playNumberDecided() { numberDecidedCount += 1 }
    func playPunchCell() { punchCellCount += 1 }
    func playReachEffect() { reachEffectCount += 1 }
    func playBingoEffect() { bingoEffectCount += 1 }
}

@MainActor
final class MockBingoSpeaker: BingoSpeechProviding {
    var isSpeaking: Bool = false
    private(set) var spokenNumbers: [Int] = []
    private(set) var spokenStatuses: [(String, PlayerToHostPayload.PlayerStatus)] = []

    func formattedPhrase(for number: Int) -> String {
        "\(BingoColumn.column(for: number).rawValue)の、\(number)番"
    }

    @discardableResult
    func speakDrawnNumber(_ number: Int, totalDrawnCount: Int) -> String? {
        spokenNumbers.append(number)
        return nil
    }

    func speakPlayerStatus(playerName: String, status: PlayerToHostPayload.PlayerStatus) {
        spokenStatuses.append((playerName, status))
    }

    func speakHistory(_ drawnNumbers: [Int]) {
        isSpeaking = true
    }

    func stopSpeaking() {
        isSpeaking = false
    }
}

// MARK: - Test Suite

final class BingoMasterTests: XCTestCase {

    // MARK: 1. BingoLogic Tests

    func testGenerateCardProducesValid25CellsWithCenterFree() {
        let cells = BingoLogic.generateCard()
        XCTAssertEqual(cells.count, 25)
        XCTAssertTrue(cells[12].isFree)
        XCTAssertEqual(cells[12].number, 0)
        XCTAssertTrue(cells[12].isPunched)
        XCTAssertTrue(BingoLogic.isValidCardNumbers(cells.map { $0.number }))
    }

    func testIsValidCardNumbersRejectsTamperedCards() {
        let validCard = BingoLogic.generateCard().map { $0.number }
        XCTAssertTrue(BingoLogic.isValidCardNumbers(validCard))

        // 1. 要素数不足
        XCTAssertFalse(BingoLogic.isValidCardNumbers(Array(validCard.prefix(24))))

        // 2. 中央FREEマス(index 12)が0以外に改ざんされた場合
        var nonZeroCenter = validCard
        nonZeroCenter[12] = 35
        XCTAssertFalse(BingoLogic.isValidCardNumbers(nonZeroCenter))

        // 3. B列(index 0)にO列の数字(75)が混入した場合
        var outOfColumnRange = validCard
        outOfColumnRange[0] = 75
        XCTAssertFalse(BingoLogic.isValidCardNumbers(outOfColumnRange))

        // 4. 同一列内で重複数字がある場合
        var duplicatedNumber = validCard
        duplicatedNumber[5] = duplicatedNumber[0]
        XCTAssertFalse(BingoLogic.isValidCardNumbers(duplicatedNumber))
    }

    func testReconstructVerifiedCellsBlocksUnpunchedOrUndrawnCheatClaims() {
        let card = BingoLogic.generateCard()
        let numbers = card.map { $0.number }
        let firstCellNumber = numbers[0]
        let secondCellNumber = numbers[1] // 司会者がまだ引いていない数字

        // 司会者は 0番目 の数字だけを引いたが、参加者が不正に 0, 1, 2, 3, 4（横1列全部）を開けたと申告したケース
        let verifiedCells = BingoLogic.reconstructVerifiedCells(
            cardNumbers: numbers,
            punchedIndices: [0, 1, 2, 3, 4, 12],
            hostDrawnNumbers: [firstCellNumber]
        )

        XCTAssertTrue(verifiedCells[0].isPunched, "司会者が引いた番号は穴あけ有効になること")
        XCTAssertFalse(verifiedCells[1].isPunched, "司会者が引いていない番号(\(secondCellNumber))は不正申告されても絶対に穴あけ無効になること")

        let evaluation = BingoLogic.evaluate(cells: verifiedCells)
        XCTAssertEqual(evaluation.status, .normal)
        XCTAssertEqual(evaluation.bingoLineCount, 0)
    }

    func testEvaluateDetectsReachAndBingoAcrossLines() {
        var cells = BingoLogic.generateCard()
        // 最上段 [0, 1, 2, 3, 4] のうち4マスを開けてリーチを検証
        for idx in [0, 1, 2, 3] {
            cells[idx].isDrawn = true
            cells[idx].isPunched = true
        }
        let reachEval = BingoLogic.evaluate(cells: cells)
        XCTAssertEqual(reachEval.status, .reach)
        XCTAssertEqual(reachEval.reachLineCount, 1)
        XCTAssertEqual(reachEval.bingoLineCount, 0)

        // 5マス目(index 4)を開けてビンゴ達成を検証
        cells[4].isDrawn = true
        cells[4].isPunched = true
        let bingoEval = BingoLogic.evaluate(cells: cells)
        XCTAssertEqual(bingoEval.status, .bingo)
        XCTAssertEqual(bingoEval.bingoLineCount, 1)
        XCTAssertTrue(bingoEval.bingoCellIDs.isSuperset(of: [0, 1, 2, 3, 4]))
    }

    // MARK: 2. SyncPayload Backward Compatibility Tests

    func testSyncPayloadBackwardCompatibleDecoding() throws {
        // 旧バージョンの最小限JSON（新規フィールド欠落）でもクラッシュせずデフォルト値でデコードできることを検証
        let legacyPlayerJSON = """
        {
            "playerName": "佐藤",
            "status": "reach",
            "reachLineCount": 2
        }
        """.data(using: .utf8)!

        let decodedPlayer = try JSONDecoder().decode(PlayerToHostPayload.self, from: legacyPlayerJSON)
        XCTAssertEqual(decodedPlayer.playerName, "佐藤")
        XCTAssertEqual(decodedPlayer.status, .reach)
        XCTAssertEqual(decodedPlayer.reachLineCount, 2)
        XCTAssertEqual(decodedPlayer.bingoLineCount, 0)
        XCTAssertTrue(decodedPlayer.cardNumbers.isEmpty)
        XCTAssertFalse(decodedPlayer.requestSync)
    }

    // MARK: 3. HostViewModel Anti-Cheat & Reset Flow Tests

    @MainActor
    func testHostViewModelRejectsFakeBingoClaimAndLocksPlayerCard() {
        let storage = InMemoryBingoStorage()
        let sync = MockBingoSyncManager()
        let audio = MockBingoAudioPlayer()
        let speaker = MockBingoSpeaker()
        let hostVM = HostViewModel(syncManager: sync, storage: storage, audioPlayer: audio, speaker: speaker)

        let originalCard = BingoLogic.generateCard().map { $0.number }

        // 司会者がまだ1球も引いていない状態で、参加者が「ビンゴ達成！」と虚偽のペイロードを送信したケース
        let fakeBingoPayload = PlayerToHostPayload(
            playerID: "player-A",
            playerName: "不正テスト選手",
            status: .bingo,
            bingoLineCount: 1,
            reachLineCount: 0,
            cardNumbers: originalCard,
            punchedIndices: [0, 1, 2, 3, 4, 12]
        )
        hostVM.handleReceivedPlayerPayload(fakeBingoPayload)

        // 司会者側で自動検算され、ステータスは .normal（ビンゴ0本）に補正されること
        let verified = hostVM.playerStatuses["player-A"]
        XCTAssertNotNil(verified)
        XCTAssertEqual(verified?.status, .normal)
        XCTAssertEqual(verified?.bingoLineCount, 0)
        XCTAssertEqual(audio.bingoEffectCount, 0)
        XCTAssertEqual(hostVM.registeredPlayerCards["player-A"], originalCard)
    }

    @MainActor
    func testHostViewModelTwoStepResetArchivesHistoryAndRegeneratesSession() {
        let storage = InMemoryBingoStorage()
        let sync = MockBingoSyncManager()
        let audio = MockBingoAudioPlayer()
        let speaker = MockBingoSpeaker()
        let hostVM = HostViewModel(syncManager: sync, storage: storage, audioPlayer: audio, speaker: speaker)

        let initialSessionID = hostVM.gameSessionID
        hostVM.commitNextNumberDraw(forcedNumber: 7)
        hostVM.commitNextNumberDraw(forcedNumber: 22)
        XCTAssertEqual(hostVM.drawnNumbers, [7, 22])

        // 1回目の確認リクエスト
        hostVM.requestResetGame()
        XCTAssertTrue(hostVM.showFirstResetConfirmationAlert)

        // 2回目の最終確認承認によるリセット実行
        hostVM.confirmResetGame()
        XCTAssertTrue(hostVM.drawnNumbers.isEmpty)
        XCTAssertNotEqual(hostVM.gameSessionID, initialSessionID)
        XCTAssertEqual(hostVM.pastGameHistory.count, 1)
        XCTAssertEqual(hostVM.pastGameHistory.first?.drawnNumbers, [7, 22])
        XCTAssertEqual(sync.sentHostPayloads.last?.action, .resetGame)
    }

    // MARK: 4. PlayerViewModel Late-Join Auto-Punch & Anti-Cheat Tests

    @MainActor
    func testPlayerViewModelLateJoinAutoPunchAndFakeHostProtection() {
        let storage = InMemoryBingoStorage()
        let sync = MockBingoSyncManager()
        let audio = MockBingoAudioPlayer()
        let playerVM = PlayerViewModel(syncManager: sync, storage: storage, audioPlayer: audio)

        let cardNumbers = playerVM.cardCells.map { $0.number }
        let targetNumber1 = cardNumbers[0]
        let targetNumber2 = cardNumbers[1]

        // 1. 本物の司会者(host-real)から途中参加時の出目を受信（手動モード）
        let realHostPayload = HostToPlayerPayload(
            action: .drawNumber,
            hostID: "host-real",
            gameSessionID: "session-1",
            latestNumber: targetNumber2,
            drawnNumbers: [targetNumber1, targetNumber2],
            lockedPlayerCards: [playerVM.playerID: cardNumbers]
        )
        playerVM.handleReceivedHostPayload(realHostPayload)

        XCTAssertEqual(playerVM.highlightedCellCount, 2, "手動モード時は出た数字2マスがハイライト状態になること")
        XCTAssertFalse(playerVM.cardCells[0].isPunched)

        // 2. 途中から「⚡ 自動穴あけモード」をONに切り替えると、すでに出ている2マスが即座に自動で開くこと
        playerVM.isAutoPunch = true
        XCTAssertTrue(playerVM.cardCells[0].isPunched)
        XCTAssertTrue(playerVM.cardCells[1].isPunched)
        XCTAssertEqual(playerVM.highlightedCellCount, 0)

        // 3. ゲーム進行中に偽ホスト(host-spoofed)からリセット信号が送られてきても無視してカードを守ることを検証
        let spoofedResetPayload = HostToPlayerPayload(
            action: .resetGame,
            hostID: "host-spoofed",
            gameSessionID: "session-hacked",
            latestNumber: nil,
            drawnNumbers: []
        )
        playerVM.handleReceivedHostPayload(spoofedResetPayload)
        XCTAssertEqual(playerVM.drawnNumbers, [targetNumber1, targetNumber2], "偽ホストからのリセット要求は遮断されること")
        XCTAssertFalse(playerVM.showHostResetNoticeAlert)
    }

    // MARK: 5. AppConfig AdMob Configuration Tests

    func testAppConfigAdMobIdentifiersAreConfigured() {
        XCTAssertTrue(AppConfig.isAdMobConfigured, "AdMobのアプリIDと広告ユニットIDが両方設定されていること")
        XCTAssertEqual(AppConfig.adMobAppID, "ca-app-pub-4261439423960578~7154869508")
        XCTAssertEqual(AppConfig.adMobBannerUnitID, "ca-app-pub-4261439423960578/9866673659")
    }
}
