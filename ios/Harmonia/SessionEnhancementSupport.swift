import Foundation
import AVFoundation
import UIKit

final class SessionToneEngine {
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var sampleRate: Double = 44_100
    private var isSetUp: Bool = false

    func startResonance(frequencies: [Double], intensity: Double, pulsePattern: [Double]) {
        let resolvedFrequencies: [Double] = frequencies.isEmpty ? [174, 285, 396] : frequencies
        playBuffer(makeResonanceBuffer(frequencies: resolvedFrequencies, intensity: intensity, pulsePattern: pulsePattern))
    }

    func startBinaural(baseFrequency: Double, beatFrequency: Double, intensity: Double) {
        playBuffer(makeBinauralBuffer(baseFrequency: baseFrequency, beatFrequency: beatFrequency, intensity: intensity))
    }

    func startIsochronic(carrierFrequency: Double, pulseFrequency: Double, intensity: Double) {
        playBuffer(makeIsochronicBuffer(carrierFrequency: carrierFrequency, pulseFrequency: pulseFrequency, intensity: intensity))
    }

    func stop() {
        playerNode?.stop()
        playerNode?.reset()
        if let engine, engine.isRunning {
            engine.pause()
        }
    }

    private func setUp() {
        guard !isSetUp else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let newEngine = AVAudioEngine()
        let newPlayerNode = AVAudioPlayerNode()

        let stereoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44_100, channels: 2, interleaved: false)!

        newEngine.attach(newPlayerNode)
        newEngine.connect(newPlayerNode, to: newEngine.mainMixerNode, format: stereoFormat)
        newEngine.mainMixerNode.outputVolume = 1

        self.engine = newEngine
        self.playerNode = newPlayerNode
        self.format = stereoFormat
        self.sampleRate = 44_100
        self.isSetUp = true
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer else {
            stop()
            return
        }

        if isSetUp {
            stop()
            isSetUp = false
            engine = nil
            playerNode = nil
            format = nil
        }

        do {
            setUp()
            guard let engine, let playerNode else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }
            playerNode.stop()
            playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
            playerNode.play()
        } catch {
            stop()
        }
    }

    private func makeResonanceBuffer(frequencies: [Double], intensity: Double, pulsePattern: [Double]) -> AVAudioPCMBuffer? {
        setUp()
        let duration: Double = 4
        return makeBuffer(duration: duration) { time in
            let clampedIntensity: Double = min(max(intensity, 0), 1)
            let pattern: [Double] = pulsePattern.isEmpty ? [0.4, 0.6, 0.3] : pulsePattern
            let patternIndex: Int = min(Int((time / duration) * Double(pattern.count)), pattern.count - 1)
            let envelope: Double = 0.28 + (0.72 * pattern[patternIndex])
            let mix: Double = frequencies.reduce(0) { partial, frequency in
                partial + sin((2 * Double.pi * frequency) * time)
            } / Double(max(frequencies.count, 1))
            let sample: Float = Float(mix * envelope * (0.08 + (0.18 * clampedIntensity)))
            return (sample, sample)
        }
    }

    private func makeBinauralBuffer(baseFrequency: Double, beatFrequency: Double, intensity: Double) -> AVAudioPCMBuffer? {
        setUp()
        let duration: Double = 2
        return makeBuffer(duration: duration) { time in
            let clampedIntensity: Double = min(max(intensity, 0), 1)
            let safeBase: Double = min(max(baseFrequency, 80), 800)
            let safeBeat: Double = min(max(beatFrequency, 1), 40)
            let leftFrequency: Double = max(60, safeBase - (safeBeat / 2))
            let rightFrequency: Double = max(60, safeBase + (safeBeat / 2))
            let amplitude: Double = 0.05 + (0.16 * clampedIntensity)
            let leftSample: Float = Float(sin((2 * Double.pi * leftFrequency) * time) * amplitude)
            let rightSample: Float = Float(sin((2 * Double.pi * rightFrequency) * time) * amplitude)
            return (leftSample, rightSample)
        }
    }

    private func makeIsochronicBuffer(carrierFrequency: Double, pulseFrequency: Double, intensity: Double) -> AVAudioPCMBuffer? {
        setUp()
        let duration: Double = 2
        return makeBuffer(duration: duration) { time in
            let clampedIntensity: Double = min(max(intensity, 0), 1)
            let safeCarrier: Double = min(max(carrierFrequency, 80), 800)
            let safePulse: Double = min(max(pulseFrequency, 1), 40)
            let carrier: Double = sin((2 * Double.pi * safeCarrier) * time)
            let modulation: Double = max(0.12, sin((2 * Double.pi * safePulse) * time))
            let sample: Float = Float(carrier * modulation * (0.05 + (0.18 * clampedIntensity)))
            return (sample, sample)
        }
    }

    private func makeBuffer(duration: Double, sample: (_ time: Double) -> (Float, Float)) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frameCount: AVAudioFrameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer: AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
            return nil
        }

        buffer.frameLength = frameCount
        let channelCount: Int = Int(format.channelCount)
        let leftChannel: UnsafeMutablePointer<Float> = channelData[0]
        let rightChannel: UnsafeMutablePointer<Float> = channelData[min(1, channelCount - 1)]

        for frame in 0..<Int(frameCount) {
            let time: Double = Double(frame) / sampleRate
            let stereoSample: (Float, Float) = sample(time)
            leftChannel[frame] = stereoSample.0
            rightChannel[frame] = stereoSample.1

            if channelCount > 2 {
                for index in 2..<channelCount {
                    channelData[index][frame] = (stereoSample.0 + stereoSample.1) * 0.5
                }
            }
        }

        return buffer
    }
}

final class HarmoniaPulsePlayer {
    private var task: Task<Void, Never>?

    func start(pattern: [Double], intensity: Double, sensitivity: Double) {
        stop()

        let pulsePattern: [Double] = pattern.isEmpty ? [0.4, 0.6, 0.3] : pattern
        let resolvedIntensity: Double = min(max(intensity * sensitivity, 0), 1)
        guard resolvedIntensity > 0.05 else {
            return
        }

        task = Task {
            while Task.isCancelled == false {
                for value in pulsePattern {
                    if Task.isCancelled {
                        return
                    }

                    let pulseStrength: Double = min(max(value * resolvedIntensity, 0.2), 1)
                    await Self.playImpact(strength: pulseStrength)
                    let interval: Double = max(0.18, 0.72 - (value * 0.38))
                    try? await Task.sleep(for: .seconds(interval))
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    @MainActor
    private static func playImpact(strength: Double) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        switch strength {
        case 0.75...:
            style = .heavy
        case 0.45...:
            style = .medium
        default:
            style = .light
        }

        let generator: UIImpactFeedbackGenerator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(strength))
    }
}
