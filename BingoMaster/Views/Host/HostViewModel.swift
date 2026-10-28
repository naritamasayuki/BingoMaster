import Combine
import Foundation
import MultipeerConnectivity

@MainActor
final class HostViewModel: ObservableObject {
    @Published private(set) var drawnNumbers: [Int] = []
    @Published private(set) var displayNumber: Int? = nil
    @Published private(set) var isSpinning: Bool = false

    /// 画面上部に表示するトーストバナーメッセージ（合いの手・リーチ/ビンゴ通知）
    @Published var toastMessage: String? = nil
    @Published var toastIsCelebration: Bool = false

    /// 参加者ごとの最新ステータス一覧
    @Published private(set) var playerStatuses: [String: PlayerToHostPayload] = [:]

    /// 安全な2段階リセット用アラートフラグ
    @Published var showResetConfirmationAlert: Bool = false
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

    /// 次の数字を抽選する（約1.5秒間のルーレット減速演出つき）
    func drawNextNumber() {
        let candidates = remainingNumbers
        guard !isSpinning, !candidates.isEmpty else { return }

        isSpinning = true
        speaker.stopSpeaking()

        // 減速インターバル配列（合計 約1.5秒: 0.05秒から0.15秒へ徐々に減速）
        let intervals: [TimeInterval] = [
            0.05, 0.05, 0.05, 0.05, 0.06,
            0.06, 0.07, 0.07, 0.08, 0.09,
            0.10, 0.11, 0.12, 0.13, 0.14,
            0.15, 0.15
        ]

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
            self.drawnNumbers.append(finalNumber)
            self.isSpinning = false

            // 永続化
            BingoStorage.saveHostDrawnNumbers(self.drawnNumbers)

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

    /// リセット実行（確認ダイアログ承認後に呼ばれる）
    func confirmResetGame() {
        spinTask?.cancel()
        isSpinning = false
        speaker.stopSpeaking()

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
