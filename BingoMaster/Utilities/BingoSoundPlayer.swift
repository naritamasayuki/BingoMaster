import AudioToolbox
import AVFoundation
import UIKit

/// 効果音・触覚フィードバック（Haptics）再生の抽象プロトコル。
/// ユニットテスト実行時に実機スピーカーやバイブレーションを鳴らさずに検証できるよう分離している。
@MainActor
protocol BingoAudioPlaying: AnyObject {
    func playSpinTick()
    func playNumberDecided()
    func playPunchCell()
    func playReachEffect()
    func playBingoEffect()
}

@MainActor
final class BingoSoundPlayer: BingoAudioPlaying {
    static let shared = BingoSoundPlayer()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// 0.04秒間隔の高速ルーレット回転中でも前の音が途切れないよう、複数のプレイヤーを循環プールして再生する
    private var tickPlayers: [AVAudioPlayer] = []
    private var currentTickPlayerIndex: Int = 0

    private var decidedPlayer: AVAudioPlayer?
    private var punchPlayer: AVAudioPlayer?
    private var reachPlayer: AVAudioPlayer?
    private var bingoPlayer: AVAudioPlayer?

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notificationGenerator.prepare()

        configureAudioSession()
        prepareSynthesizedSounds()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            BingoLogger.logError(
                BingoLogger.audio,
                context: "AVAudioSessionの初期化に失敗しました（システムサウンドへフォールバックします）",
                error: error
            )
        }
    }

    /// 外部音源ファイルのアセット管理コストやライセンス問題を避けるため、標準フレームワークのみでPCM波形を合成する
    private func prepareSynthesizedSounds() {
        let tickWavData = Self.makeRouletteTickWAV()
        for index in 0..<8 {
            do {
                let player = try AVAudioPlayer(data: tickWavData)
                player.volume = 0.85
                player.prepareToPlay()
                tickPlayers.append(player)
            } catch {
                BingoLogger.logError(
                    BingoLogger.audio,
                    context: "ルーレット回転音プレイヤー(\(index))の生成に失敗しました",
                    error: error
                )
            }
        }

        let decidedWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 523.25, start: 0.00, duration: 0.12), // C5
                (freq: 659.25, start: 0.06, duration: 0.12), // E5
                (freq: 783.99, start: 0.12, duration: 0.15), // G5
                (freq: 1046.50, start: 0.18, duration: 0.45) // C6
            ],
            totalDuration: 0.65
        )
        decidedPlayer = makeConfiguredPlayer(from: decidedWavData, volume: 1.0, label: "番号確定チャイム")

        let punchWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 440.0, start: 0.00, duration: 0.06),
                (freq: 880.0, start: 0.04, duration: 0.14)
            ],
            totalDuration: 0.20
        )
        punchPlayer = makeConfiguredPlayer(from: punchWavData, volume: 0.9, label: "マス穴あけスタンプ音")

        let reachWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 587.33, start: 0.00, duration: 0.10), // D5
                (freq: 659.25, start: 0.09, duration: 0.10), // E5
                (freq: 783.99, start: 0.18, duration: 0.10), // G5
                (freq: 1174.66, start: 0.27, duration: 0.38) // D6
            ],
            totalDuration: 0.68
        )
        reachPlayer = makeConfiguredPlayer(from: reachWavData, volume: 1.0, label: "リーチ効果音")

        let bingoWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 523.25, start: 0.00, duration: 0.12), // C5
                (freq: 523.25, start: 0.13, duration: 0.12), // C5
                (freq: 523.25, start: 0.26, duration: 0.12), // C5
                (freq: 659.25, start: 0.40, duration: 0.22), // E5
                (freq: 783.99, start: 0.62, duration: 0.22), // G5
                (freq: 1046.50, start: 0.85, duration: 0.60) // C6
            ],
            totalDuration: 1.50
        )
        bingoPlayer = makeConfiguredPlayer(from: bingoWavData, volume: 1.0, label: "ビンゴファンファーレ音")
    }

    private func makeConfiguredPlayer(from data: Data, volume: Float, label: String) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            player.prepareToPlay()
            return player
        } catch {
            BingoLogger.logError(
                BingoLogger.audio,
                context: "\(label)のAVAudioPlayer初期化に失敗しました",
                error: error
            )
            return nil
        }
    }

    func playSpinTick() {
        if !tickPlayers.isEmpty {
            let player = tickPlayers[currentTickPlayerIndex]
            currentTickPlayerIndex = (currentTickPlayerIndex + 1) % tickPlayers.count
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1104)
        }
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    func playNumberDecided() {
        if let player = decidedPlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1025)
        }
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    func playPunchCell() {
        if let player = punchPlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1105)
        }
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }

    func playReachEffect() {
        if let player = reachPlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1009)
        }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    func playBingoEffect() {
        if let player = bingoPlayer {
            player.currentTime = 0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1026)
        }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    // MARK: - PCM WAV Generator (強制アンラップを排除した安全なバイト列生成)

    static func makeRouletteTickWAV() -> Data {
        let sampleRate = 44100
        let duration = 0.045
        let numSamples = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            let envelope = exp(-t * 65.0)
            let wave = 0.7 * sin(2.0 * .pi * 880.0 * t) + 0.3 * sin(2.0 * .pi * 1760.0 * t)
            let value = max(-1.0, min(1.0, wave * envelope * 0.65))
            samples[i] = Int16(value * Double(Int16.max))
        }

        return encodePCM16ToWAV(samples: samples, sampleRate: sampleRate)
    }

    static func makeChordArpeggioWAV(
        notes: [(freq: Double, start: Double, duration: Double)],
        totalDuration: Double
    ) -> Data {
        let sampleRate = 44100
        let numSamples = max(1, Int(Double(sampleRate) * max(0.01, totalDuration)))
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var mixed = 0.0

            for note in notes where note.duration > 0 {
                if t >= note.start && t <= (note.start + note.duration) {
                    let localT = t - note.start
                    let attack = min(1.0, localT / 0.008)
                    let decay = exp(-localT * (4.5 / note.duration))
                    let env = attack * decay
                    let fundamental = sin(2.0 * .pi * note.freq * localT)
                    let harmonic = 0.35 * sin(2.0 * .pi * (note.freq * 2.0) * localT)
                    mixed += (fundamental + harmonic) * env * 0.40
                }
            }

            let clamped = max(-1.0, min(1.0, mixed))
            samples[i] = Int16(clamped * Double(Int16.max))
        }

        return encodePCM16ToWAV(samples: samples, sampleRate: sampleRate)
    }

    private static func encodePCM16ToWAV(samples: [Int16], sampleRate: Int) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Int(numChannels) * Int(bitsPerSample / 8))
        let blockAlign = UInt16(numChannels * (bitsPerSample / 8))
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize = 36 + dataSize

        var data = Data()
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1
        let sampleRate32 = UInt32(sampleRate)
        data.append(withUnsafeBytes(of: subchunk1Size.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate32.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            data.append(
                UnsafeBufferPointer(
                    start: UnsafeRawPointer(baseAddress).assumingMemoryBound(to: UInt8.self),
                    count: Int(dataSize)
                )
            )
        }

        return data
    }
}
