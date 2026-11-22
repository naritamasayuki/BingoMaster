import Foundation
import AVFoundation
import UIKit

/// 防犯ブザー（合成サイレン音＋日本語音声威嚇＋画面点滅）を制御するクラス
@MainActor
final class SecurityBuzzerManager: ObservableObject {
    @Published var isBuzzerActive: Bool = false
    @Published var isFlashScreenRed: Bool = false
    @Published var useVoiceAlert: Bool = true

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var flashTimer: Timer?
    private var voiceTimer: Timer?
    private var phase: Double = 0.0
    private var sweepPhase: Double = 0.0

    func toggleBuzzer() {
        if isBuzzerActive {
            stopBuzzer()
        } else {
            startBuzzer()
        }
    }

    func startBuzzer() {
        guard !isBuzzerActive else { return }
        isBuzzerActive = true

        // 触覚フィードバック
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        configureAudioSession()
        startSirenEngine()
        startScreenFlashTimer()

        if useVoiceAlert {
            speakEmergencyPhrase()
            voiceTimer = Timer.scheduledTimer(withTimeInterval: 6.5, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isBuzzerActive, self.useVoiceAlert else { return }
                    self.speakEmergencyPhrase()
                }
            }
        }
    }

    func stopBuzzer() {
        isBuzzerActive = false
        isFlashScreenRed = false

        flashTimer?.invalidate()
        flashTimer = nil

        voiceTimer?.invalidate()
        voiceTimer = nil

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        if let engine = audioEngine {
            engine.stop()
            if let node = sourceNode {
                engine.detach(node)
            }
        }
        audioEngine = nil
        sourceNode = nil
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // シミュレータ等で失敗してもクラッシュさせない
        }
    }

    private func startSirenEngine() {
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0

        phase = 0.0
        sweepPhase = 0.0

        // 防犯ブザー特有の2400Hz〜3100Hz高速スイープ警報音を生成
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // 1秒間に約4往復する緊迫した防犯ブザー周波数変調
                self.sweepPhase += (4.5 * 2.0 * .pi) / sampleRate
                if self.sweepPhase > 2.0 * .pi {
                    self.sweepPhase -= 2.0 * .pi
                }

                let modulation = (sin(self.sweepPhase) + 1.0) * 0.5 // 0.0 ... 1.0
                let frequency = 2200.0 + (modulation * 950.0) // 2200Hz ... 3150Hz

                self.phase += (2.0 * .pi * frequency) / sampleRate
                if self.phase > 2.0 * .pi {
                    self.phase -= 2.0 * .pi
                }

                // 倍音を含めて通りやすいブザー音にする
                let sample = Float(sin(self.phase) * 0.55 + (sin(self.phase * 2.0) * 0.2))

                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    if frame < buf.count {
                        buf[frame] = sample
                    }
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: mainMixer, format: outputFormat)

        do {
            try engine.start()
            self.audioEngine = engine
            self.sourceNode = node
        } catch {
            // オーディオエンジン起動失敗時はシステムサウンドでフォールバック
            AudioServicesPlaySystemSound(1005)
        }
    }

    private func startScreenFlashTimer() {
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isBuzzerActive else { return }
                self.isFlashScreenRed.toggle()
            }
        }
    }

    private func speakEmergencyPhrase() {
        guard !speechSynthesizer.isSpeaking else { return }
        let utterance = AVSpeechUtterance(string: "緊急事態です！防犯ブザーが作動しています。周囲の方、助けてください！")
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.53
        utterance.pitchMultiplier = 1.15
        utterance.volume = 1.0
        speechSynthesizer.speak(utterance)
    }
}
