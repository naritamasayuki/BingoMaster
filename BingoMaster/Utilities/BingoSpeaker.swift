import AVFoundation
import Foundation

@MainActor
final class BingoSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = BingoSpeaker()

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    /// 司会アシスト（合いの手）のランダムフレーズ一覧
    private let interjectionPhrases: [String] = [
        "リーチの人、いますか〜？",
        "ビンゴの人、おりますか〜？",
        "そろそろ穴が空いてきましたか〜？",
        "お手元のカード、よく確認してくださいね〜！",
        "まだまだチャンスはありますよ〜！"
    ]

    override private init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // シミュレータ環境等で設定失敗してもクラッシュさせない
        }
    }

    /// 番号の日本語読み上げ文字列を生成（例: "Bの、7番"）
    func formattedPhrase(for number: Int) -> String {
        let column = BingoColumn.column(for: number)
        return "\(column.rawValue)の、\(number)番"
    }

    /// 数字確定時の2回繰り返し読み上げ + 条件を満たせば40%の確率で合いの手を発声
    /// - Returns: 発生した合いの手メッセージ（トースト表示用、発生しない場合は nil）
    @discardableResult
    func speakDrawnNumber(_ number: Int, totalDrawnCount: Int) -> String? {
        stopSpeaking()

        let phrase = formattedPhrase(for: number)

        // 1回目の読み上げ
        let firstUtterance = makeUtterance(text: "\(phrase)！", rate: 0.50, postDelay: 0.35)
        // 2回目の復唱
        let secondUtterance = makeUtterance(text: "\(phrase)！", rate: 0.48, postDelay: 0.40)

        synthesizer.speak(firstUtterance)
        synthesizer.speak(secondUtterance)

        // 出目が5個以上出た後、40%の確率で司会アシスト（合いの手）を追加
        if totalDrawnCount >= 5 && Double.random(in: 0..<1) < 0.40 {
            if let interjection = interjectionPhrases.randomElement() {
                let assistUtterance = makeUtterance(text: interjection, rate: 0.50, pitch: 1.08, postDelay: 0.2)
                synthesizer.speak(assistUtterance)
                return interjection
            }
        }

        return nil
    }

    /// 参加者からのリーチ・ビンゴ通知を受信した際の優先実況アナウンス
    func speakPlayerStatus(playerName: String, status: PlayerToHostPayload.PlayerStatus) {
        let announcement: String
        switch status {
        case .reach:
            announcement = "おっと、\(playerName)さんがリーチになりました〜！"
        case .bingo:
            announcement = "おめでとうございます！\(playerName)さん、ビンゴ達成です！"
        case .normal:
            return
        }

        let utterance = makeUtterance(text: announcement, rate: 0.50, pitch: 1.12, postDelay: 0.25)
        synthesizer.speak(utterance)
    }

    /// これまでの出目履歴をゆっくり一括読み上げ（rate = 0.42）
    func speakHistory(_ drawnNumbers: [Int]) {
        guard !drawnNumbers.isEmpty else { return }
        stopSpeaking()

        let introText = "出目履歴をゆっくり読み上げます。全部で\(drawnNumbers.count)個です。"
        let introUtterance = makeUtterance(text: introText, rate: 0.42, postDelay: 0.50)
        synthesizer.speak(introUtterance)

        for number in drawnNumbers {
            let text = "\(formattedPhrase(for: number))。"
            let itemUtterance = makeUtterance(text: text, rate: 0.42, postDelay: 0.45)
            synthesizer.speak(itemUtterance)
        }

        let outroUtterance = makeUtterance(text: "以上です。", rate: 0.42, postDelay: 0.1)
        synthesizer.speak(outroUtterance)
    }

    /// 音声読み上げを即座に停止
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    private func makeUtterance(
        text: String,
        rate: Float,
        pitch: Float = 1.0,
        postDelay: TimeInterval = 0.2
    ) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.postUtteranceDelay = postDelay
        return utterance
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
