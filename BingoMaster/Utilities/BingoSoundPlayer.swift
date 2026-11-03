import AudioToolbox
import AVFoundation
import UIKit

@MainActor
final class BingoSoundPlayer {
    static let shared = BingoSoundPlayer()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    /// 高速連打（0.04秒間隔のルーレット回転）でも音が重なって途切れないよう複数プレイヤーをプール
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
            // エラー時は無視
        }
    }

    /// 外部音源ファイルに依存せず、標準フレームワークのみでクリアな効果音（WAVデータ）を生成
    private func prepareSynthesizedSounds() {
        // 1. ルーレット回転音（小気味よい電子ルーレット「ピッ / カチッ」音を8個プール）
        let tickWavData = Self.makeRouletteTickWAV()
        for _ in 0..<8 {
            if let player = try? AVAudioPlayer(data: tickWavData) {
                player.volume = 0.85
                player.prepareToPlay()
                tickPlayers.append(player)
            }
        }

        // 2. 番号確定時の決定チャイム音（「ピロリーン♪」華やかな和音チャイム）
        let decidedWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 523.25, start: 0.00, duration: 0.12), // C5
                (freq: 659.25, start: 0.06, duration: 0.12), // E5
                (freq: 783.99, start: 0.12, duration: 0.15), // G5
                (freq: 1046.50, start: 0.18, duration: 0.45) // C6
            ],
            totalDuration: 0.65
        )
        decidedPlayer = try? AVAudioPlayer(data: decidedWavData)
        decidedPlayer?.volume = 1.0
        decidedPlayer?.prepareToPlay()

        // 3. マス穴あけスタンプ音（「ポンッ！」）
        let punchWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 440.0, start: 0.00, duration: 0.06),
                (freq: 880.0, start: 0.04, duration: 0.14)
            ],
            totalDuration: 0.20
        )
        punchPlayer = try? AVAudioPlayer(data: punchWavData)
        punchPlayer?.volume = 0.9
        punchPlayer?.prepareToPlay()

        // 4. リーチ効果音（「テレレレッ♪」）
        let reachWavData = Self.makeChordArpeggioWAV(
            notes: [
                (freq: 587.33, start: 0.00, duration: 0.10), // D5
                (freq: 659.25, start: 0.09, duration: 0.10), // E5
                (freq: 783.99, start: 0.18, duration: 0.10), // G5
                (freq: 1174.66, start: 0.27, duration: 0.38) // D6
            ],
            totalDuration: 0.68
        )
        reachPlayer = try? AVAudioPlayer(data: reachWavData)
        reachPlayer?.volume = 1.0
        reachPlayer?.prepareToPlay()

        // 5. ビンゴ達成ファンファーレ音
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
        bingoPlayer = try? AVAudioPlayer(data: bingoWavData)
        bingoPlayer?.volume = 1.0
        bingoPlayer?.prepareToPlay()
    }

    /// ルーレット回転中の各コマ切り替わり時の回転音と軽い振動
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

    /// 番号確定時の決定チャイム音と振動
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

    /// 参加者がマスをタップして穴を開けた時のスタンプ音と強い振動 (.heavy)
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

    /// リーチ発生時の効果音と振動
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

    /// ビンゴ達成時の効果音と祝福の振動
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

    // MARK: - PCM WAV Generator (完全標準フレームワークのみでの音源合成)

    /// ルーレットの「ピッ / カチッ」という歯切れの良い回転音を合成
    private static func makeRouletteTickWAV() -> Data {
        let sampleRate = 44100
        let duration = 0.045
        let numSamples = Int(Double(sampleRate) * duration)
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            // 急速減衰エンベロープで歯切れの良いルーレットクリック音を作る
            let envelope = exp(-t * 65.0)
            // 880Hz (A5) と 1760Hz (A6) の倍音をブレンドして明るいルーレット音に
            let wave = 0.7 * sin(2.0 * .pi * 880.0 * t) + 0.3 * sin(2.0 * .pi * 1760.0 * t)
            let value = max(-1.0, min(1.0, wave * envelope * 0.65))
            samples[i] = Int16(value * Double(Int16.max))
        }

        return encodePCM16ToWAV(samples: samples, sampleRate: sampleRate)
    }

    /// 複数の音符（周波数・開始時刻・長さ）からチャイム・ファンファーレのWAVデータを合成
    private static func makeChordArpeggioWAV(
        notes: [(freq: Double, start: Double, duration: Double)],
        totalDuration: Double
    ) -> Data {
        let sampleRate = 44100
        let numSamples = Int(Double(sampleRate) * totalDuration)
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            var mixed = 0.0

            for note in notes {
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
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        data.append("fmt ".data(using: .ascii)!)
        let subchunk1Size: UInt32 = 16
        let audioFormat: UInt16 = 1 // PCM
        let sampleRate32 = UInt32(sampleRate)
        data.append(withUnsafeBytes(of: subchunk1Size.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: audioFormat.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate32.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        samples.withUnsafeBufferPointer { buffer in
            data.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: Int(dataSize)
            ))
        }

        return data
    }
}
