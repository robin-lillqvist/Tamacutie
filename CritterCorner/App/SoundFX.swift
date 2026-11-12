import AVFoundation

/// Tiny synthesized sound effects, so the game needs no audio files.
/// Uses the ambient category: respects the silent switch and mixes with other audio.
@MainActor
final class SoundFX {
    enum Effect: CaseIterable {
        case boop, pop, chomp, coin, squeak, purr, bounce, giggle, splash, whoosh, boing
        /// Xylophone bars, low to high (a pentatonic scale, so any tune sounds nice).
        case note0, note1, note2, note3, note4, note5

        static let notes: [Effect] = [.note0, .note1, .note2, .note3, .note4, .note5]
    }

    static let shared = SoundFX()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Effect: AVAudioPCMBuffer] = [:]
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.mainMixerNode.outputVolume = 0.5
        for effect in Effect.allCases { buffers[effect] = render(effect) }
        try? engine.start()
    }

    /// The mute switch. Saved, so the game stays quiet until you turn sound back on.
    /// UI tests launch with `-muted YES`.
    static let mutedKey = "muted"

    static var isMuted: Bool { UserDefaults.standard.bool(forKey: mutedKey) }

    static func play(_ effect: Effect) {
        guard !isMuted else { return }
        shared.play(effect)
    }

    private func play(_ effect: Effect) {
        guard let buffer = buffers[effect] else { return }
        if !engine.isRunning { try? engine.start() }
        let player = players[next]
        next = (next + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer)
        player.play()
    }

    // MARK: Synthesis

    private func render(_ effect: Effect) -> AVAudioPCMBuffer? {
        switch effect {
        case .boop: tones([(520, 820, 0.09)], volume: 0.5)
        case .pop: tones([(900, 1600, 0.05)], volume: 0.45)
        case .chomp: noise(bursts: 2, length: 0.045, gap: 0.05, volume: 0.35)
        case .coin: tones([(988, 988, 0.07), (1319, 1319, 0.16)], volume: 0.35)
        case .squeak: tones([(1100, 1800, 0.12)], volume: 0.35)
        case .purr: purr()
        case .bounce: tones([(240, 120, 0.07)], volume: 0.5)
        case .giggle: tones([(700, 900, 0.06), (760, 980, 0.06), (820, 1060, 0.08)], volume: 0.4)
        case .splash: noise(bursts: 1, length: 0.25, gap: 0, volume: 0.25)
        case .whoosh: tones([(900, 260, 0.55)], volume: 0.3)
        case .boing: tones([(180, 520, 0.16)], volume: 0.45)
        case .note0: tones([(523, 523, 0.4)], volume: 0.4)
        case .note1: tones([(587, 587, 0.4)], volume: 0.4)
        case .note2: tones([(659, 659, 0.4)], volume: 0.4)
        case .note3: tones([(784, 784, 0.4)], volume: 0.4)
        case .note4: tones([(880, 880, 0.4)], volume: 0.4)
        case .note5: tones([(1047, 1047, 0.4)], volume: 0.4)
        }
    }

    /// A sequence of sine sweeps (from Hz, to Hz, seconds) with soft attack and decay.
    private func tones(_ parts: [(Double, Double, Double)], volume: Float) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let total = parts.reduce(0) { $0 + Int($1.2 * rate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let data = buffer.floatChannelData?[0] else { return nil }
        var index = 0
        var phase = 0.0
        for (from, to, duration) in parts {
            let count = Int(duration * rate)
            for i in 0..<count {
                let t = Double(i) / Double(count)
                let frequency = from + (to - from) * t
                phase += 2 * .pi * frequency / rate
                let envelope = min(1, t * 12) * pow(1 - t, 1.6)
                data[index] = Float(sin(phase) * envelope) * volume
                index += 1
            }
        }
        buffer.frameLength = AVAudioFrameCount(total)
        return buffer
    }

    private func noise(bursts: Int, length: Double, gap: Double, volume: Float) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let burst = Int(length * rate)
        let pause = Int(gap * rate)
        let total = bursts * burst + max(0, bursts - 1) * pause
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let data = buffer.floatChannelData?[0] else { return nil }
        var index = 0
        var smooth: Float = 0
        for b in 0..<bursts {
            for i in 0..<burst {
                let t = Float(i) / Float(burst)
                smooth = smooth * 0.6 + Float.random(in: -1...1) * 0.4
                data[index] = smooth * (1 - t) * volume
                index += 1
            }
            if b < bursts - 1 {
                for _ in 0..<pause {
                    data[index] = 0
                    index += 1
                }
            }
        }
        buffer.frameLength = AVAudioFrameCount(total)
        return buffer
    }

    private func purr() -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let count = Int(0.45 * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let data = buffer.floatChannelData?[0] else { return nil }
        for i in 0..<count {
            let time = Double(i) / rate
            let t = Double(i) / Double(count)
            let flutter = 0.5 + 0.5 * sin(2 * .pi * 24 * time)
            let tone = sin(2 * .pi * 110 * time) + 0.5 * sin(2 * .pi * 220 * time)
            let envelope = min(1, t * 6) * (1 - t)
            data[i] = Float(tone * flutter * envelope) * 0.25
        }
        buffer.frameLength = AVAudioFrameCount(count)
        return buffer
    }
}
