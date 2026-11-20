import AVFoundation
import Foundation

/// 多言語音声読み上げ機能の抽象プロトコル。
/// テスト実行時に AVSpeechSynthesizer を起動せず読み上げ呼び出し履歴を検証できるようにするため定義している。
@MainActor
protocol BingoSpeechProviding: AnyObject {
    var isSpeaking: Bool { get }
    func formattedPhrase(for number: Int) -> String
    @discardableResult func speakDrawnNumber(_ number: Int, totalDrawnCount: Int) -> String?
    func speakPlayerStatus(playerName: String, status: PlayerToHostPayload.PlayerStatus)
    func speakHistory(_ drawnNumbers: [Int])
    func stopSpeaking()
}

@MainActor
final class BingoSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, BingoSpeechProviding {
    static let shared = BingoSpeaker()

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    /// 司会者が1人で進行する際も会場が盛り上がるよう、中盤以降にランダムで挿入する合いの手フレーズ
    private var interjectionPhrases: [String] {
        [
            String(localized: "リーチの人、いますか〜？"),
            String(localized: "ビンゴの人、おりますか〜？"),
            String(localized: "そろそろ穴が空いてきましたか〜？"),
            String(localized: "お手元のカード、よく確認してくださいね〜！"),
            String(localized: "まだまだチャンスはありますよ〜！")
        ]
    }

    /// システムの優先言語設定に応じた AVSpeechSynthesisVoice の言語コードを返す
    nonisolated static func preferredVoiceLanguageCode(for preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard let firstLanguage = preferredLanguages.first?.lowercased() else {
            return "ja-JP"
        }
        if firstLanguage.hasPrefix("ja") {
            return "ja-JP"
        }
        if firstLanguage.hasPrefix("zh-hans") || firstLanguage.hasPrefix("zh-cn") || firstLanguage.hasPrefix("zh-sg") {
            return "zh-CN"
        }
        if firstLanguage.hasPrefix("zh-hant") || firstLanguage.hasPrefix("zh-tw") || firstLanguage.hasPrefix("zh-hk") || firstLanguage.hasPrefix("zh-mo") {
            return "zh-TW"
        }
        if firstLanguage.hasPrefix("zh") {
            return "zh-CN"
        }
        return "en-US"
    }

    override private init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            BingoLogger.logError(
                BingoLogger.speech,
                context: "音声合成用AVAudioSessionの設定に失敗しました",
                error: error
            )
        }
    }

    func formattedPhrase(for number: Int) -> String {
        let column = BingoColumn.column(for: number)
        return String(localized: "\(column.rawValue)の、\(number)番")
    }

    @discardableResult
    func speakDrawnNumber(_ number: Int, totalDrawnCount: Int) -> String? {
        guard (1...75).contains(number) else {
            BingoLogger.logWarning(BingoLogger.speech, context: "範囲外の抽選番号(\(number))の読み上げ要求を無視しました")
            return nil
        }
        stopSpeaking()

        let phrase = formattedPhrase(for: number)

        // 決定チャイム音と重なって聞き取りづらくなるのを防ぐため preUtteranceDelay を設け、聞き逃し防止のため2回繰り返す
        let firstUtterance = makeUtterance(text: "\(phrase)！", rate: 0.50, postDelay: 0.35)
        firstUtterance.preUtteranceDelay = 0.35
        let secondUtterance = makeUtterance(text: "\(phrase)！", rate: 0.48, postDelay: 0.40)

        synthesizer.speak(firstUtterance)
        synthesizer.speak(secondUtterance)

        if totalDrawnCount >= 5 && Double.random(in: 0..<1) < 0.40 {
            if let interjection = interjectionPhrases.randomElement() {
                let assistUtterance = makeUtterance(text: interjection, rate: 0.50, pitch: 1.08, postDelay: 0.2)
                synthesizer.speak(assistUtterance)
                return interjection
            }
        }

        return nil
    }

    func speakPlayerStatus(playerName: String, status: PlayerToHostPayload.PlayerStatus) {
        let announcement: String
        switch status {
        case .reach:
            announcement = String(localized: "おっと、\(playerName)さんがリーチになりました〜！")
        case .bingo:
            announcement = String(localized: "おめでとうございます！\(playerName)さん、ビンゴ達成です！")
        case .normal:
            return
        }

        let utterance = makeUtterance(text: announcement, rate: 0.50, pitch: 1.12, postDelay: 0.25)
        synthesizer.speak(utterance)
    }

    /// 途中参加者や聞き逃した参加者が手元のカードを探しやすいよう、通常より低い rate (0.32) と十分な間隔 (1.3秒) で読み上げる
    func speakHistory(_ drawnNumbers: [Int]) {
        guard !drawnNumbers.isEmpty else { return }
        stopSpeaking()

        let introText = String(localized: "これまでの出目履歴を、ゆっくり読み上げます。全部で、\(drawnNumbers.count)個です。")
        let introUtterance = makeUtterance(text: introText, rate: 0.35, postDelay: 1.0)
        synthesizer.speak(introUtterance)

        for number in drawnNumbers {
            let column = BingoColumn.column(for: number)
            let text = String(localized: "\(column.rawValue)の、、\(number)番。")
            let itemUtterance = makeUtterance(text: text, rate: 0.32, postDelay: 1.3)
            synthesizer.speak(itemUtterance)
        }

        let outroUtterance = makeUtterance(text: String(localized: "以上、\(drawnNumbers.count)個でした。"), rate: 0.35, postDelay: 0.2)
        synthesizer.speak(outroUtterance)
    }

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
        utterance.voice = AVSpeechSynthesisVoice(language: Self.preferredVoiceLanguageCode())
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
