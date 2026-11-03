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

    /// 自動保存された過去のゲーム履歴一覧
    @Published private(set) var pastGameHistory: [PastGameRecord] = []

    /// 画面上部に表示するトーストバナーメッセージ（合いの手・リーチ/ビンゴ通知）
    @Published var toastMessage: String? = nil
    @Published var toastIsCelebration: Bool = false

    /// 参加者ごとの最新ステータス一覧
    @Published private(set) var playerStatuses: [String: PlayerToHostPayload] = [:]

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
        let saved = BingoStorage.loadHostDrawnNumbers()
        self.drawnNumbers = saved
        self.displayNumber = saved.last
        self.pastGameHistory = BingoStorage.loadPastGameHistory()

        if let savedModeRaw = BingoStorage.loadHostSpinDurationMode(),
           let savedMode = SpinDurationMode(rawValue: savedModeRaw) {
            self.spinDurationMode = savedMode
        }

        setupSyncCallbacks()
    }

    private func setupSyncCallbacks() {
        // 新規または再接続した参加者に現在の全出目リストを即時送信
        syncManager.onPeerConnectedToHost = { [weak self] peerID in
            guard let self = self else { return }
            let payload = HostToPlayerPayload(
                action: .drawNumber,
                latestNumber: self.drawnNumbers.last,
                drawnNumbers: self.drawnNumbers
            )
            self.syncManager.sendHostPayload(payload, to: [peerID])
        }

        // 参加者からのリーチ・ビンゴ通知を受信
        syncManager.onReceivePlayerPayload = { [weak self] payload in
            guard let self = self else { return }
            let previousStatus = self.playerStatuses[payload.playerName]?.status
            self.playerStatuses[payload.playerName] = payload

            guard previousStatus != payload.status else { return }

            switch payload.status {
            case .bingo:
                BingoSoundPlayer.shared.playBingoEffect()
                self.showToast("🎊 \(payload.playerName)さんがビンゴ達成です！", isCelebration: true)
                self.speaker.speakPlayerStatus(playerName: payload.playerName, status: .bingo)
            case .reach:
                BingoSoundPlayer.shared.playReachEffect()
                self.showToast("🔥 おっと、\(payload.playerName)さんがリーチになりました〜！（\(payload.reachLineCount)ライン）", isCelebration: false)
                self.speaker.speakPlayerStatus(playerName: payload.playerName, status: .reach)
            case .normal:
                break
            }
        }
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

            // 決定チャイム音と振動
            BingoSoundPlayer.shared.playNumberDecided()

            // 全参加者にブロードキャスト配信
            let payload = HostToPlayerPayload(
                action: .drawNumber,
                latestNumber: finalNumber,
                drawnNumbers: self.drawnNumbers
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

        // リセット前のゲーム履歴を自動アーカイブ保存
        if !drawnNumbers.isEmpty {
            BingoStorage.archiveGameHistory(drawnNumbers)
            pastGameHistory = BingoStorage.loadPastGameHistory()
        }

        drawnNumbers.removeAll()
        displayNumber = nil
        playerStatuses.removeAll()
        toastMessage = nil

        BingoStorage.clearHostData()

        let resetPayload = HostToPlayerPayload(
            action: .resetGame,
            latestNumber: nil,
            drawnNumbers: []
        )
        syncManager.sendHostPayload(resetPayload)

        showResetCompletedAlert = true
    }

    /// 過去の自動保存されたゲーム履歴から状態を復元する
    func restoreFromPastRecord(_ record: PastGameRecord) {
        guard !isSpinning else { return }
        speaker.stopSpeaking()

        drawnNumbers = record.drawnNumbers
        displayNumber = record.drawnNumbers.last

        let payload = HostToPlayerPayload(
            action: .drawNumber,
            latestNumber: self.drawnNumbers.last,
            drawnNumbers: self.drawnNumbers
        )
        syncManager.sendHostPayload(payload)
        showToast("📂 \(record.formattedDate) のゲーム履歴（\(record.drawnNumbers.count)球）を復元しました", isCelebration: false)
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
