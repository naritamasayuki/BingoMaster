import AudioToolbox
import UIKit

@MainActor
final class BingoSoundPlayer {
    static let shared = BingoSoundPlayer()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationGenerator.prepare()
    }

    /// ルーレット回転中の各コマ切り替わり時のクリック音と軽い振動
    func playSpinTick() {
        AudioServicesPlaySystemSound(1104) // 軽快なシステムタップ音
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// 番号確定時の決定チャイム音と振動
    func playNumberDecided() {
        AudioServicesPlaySystemSound(1025) // ファンファーレ風チャイム音
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    /// 参加者がマスをタップして穴を開けた時のスタンプ音と強い振動 (.heavy)
    func playPunchCell() {
        AudioServicesPlaySystemSound(1105) // スタンプ風システム音
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    /// リーチ発生時の効果音と振動
    func playReachEffect() {
        AudioServicesPlaySystemSound(1009)
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    /// ビンゴ達成時の効果音と祝福の振動
    func playBingoEffect() {
        AudioServicesPlaySystemSound(1026)
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }
}
