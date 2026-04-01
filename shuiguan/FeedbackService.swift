import AVFoundation
import Combine
import UIKit

@MainActor
final class FeedbackService: ObservableObject {
    private struct ToneStep {
        let frequency: Double
        let duration: Double
        let amplitude: Double
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pourPlayer = AVAudioPlayerNode()
    private let tapImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let sampleRate: Double = 44_100
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
    private var prepared = false

    init() {
        guard let format else { return }
        engine.attach(player)
        engine.attach(pourPlayer)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(pourPlayer, to: engine.mainMixerNode, format: format)
        prepareHaptics()
    }

    func playTap(using settings: GameSettings) {
        if settings.soundEnabled {
            playTapTone()
        }

        if settings.hapticsEnabled {
            triggerTapImpact()
        }
    }

    func playPourStart(duration: Double, using settings: GameSettings) {
        stopPourTone()
        guard settings.soundEnabled else { return }
        playPourTone(duration: duration)
    }

    func playSuccess(using settings: GameSettings) {
        stopPourTone()

        if settings.soundEnabled {
            playSuccessTone()
        }

        guard settings.hapticsEnabled else { return }
        triggerNotification(.success)
    }

    func playFailure(using settings: GameSettings) {
        stopPourTone()

        if settings.soundEnabled {
            playFailureTone()
        }

        guard settings.hapticsEnabled else { return }
        triggerNotification(.warning)
    }

    func previewSoundToggleEnabled() {
        playTapTone()
    }

    func previewHapticsToggleEnabled() {
        triggerTapImpact()
    }

    func stopPour() {
        stopPourTone()
    }

    func activateForForeground(using settings: GameSettings) {
        prepareHaptics()
        guard settings.soundEnabled else { return }
        prepareAudioIfNeeded()
    }

    func suspendForBackground() {
        player.stop()
        pourPlayer.stop()
        engine.stop()
        prepared = false

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore teardown failures and retry on next activation.
        }
    }
}

private extension FeedbackService {
    func playTapTone() {
        play([
            ToneStep(frequency: 1040, duration: 0.04, amplitude: 0.16),
            ToneStep(frequency: 1360, duration: 0.03, amplitude: 0.12)
        ])
    }

    func playPourTone(duration: Double) {
        guard let buffer = buildPourBuffer(duration: duration * 0.92) else { return }
        prepareAudioIfNeeded()
        guard prepared else { return }

        pourPlayer.stop()
        pourPlayer.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        pourPlayer.play()
    }

    func playSuccessTone() {
        play([
            ToneStep(frequency: 780, duration: 0.07, amplitude: 0.16),
            ToneStep(frequency: 1040, duration: 0.08, amplitude: 0.18),
            ToneStep(frequency: 1320, duration: 0.12, amplitude: 0.16)
        ])
    }

    func playFailureTone() {
        play([
            ToneStep(frequency: 460, duration: 0.08, amplitude: 0.16),
            ToneStep(frequency: 360, duration: 0.12, amplitude: 0.14)
        ])
    }

    func prepareHaptics() {
        tapImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    func triggerTapImpact() {
        tapImpactGenerator.impactOccurred(intensity: 0.65)
        tapImpactGenerator.prepare()
    }

    func triggerNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    func stopPourTone() {
        pourPlayer.stop()
    }

    private func play(_ steps: [ToneStep]) {
        guard let buffer = buildBuffer(steps: steps) else { return }
        prepareAudioIfNeeded()
        guard prepared else { return }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    func prepareAudioIfNeeded() {
        guard !prepared else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
            try engine.start()
            prepared = true
        } catch {
            prepared = false
        }
    }

    private func buildBuffer(steps: [ToneStep]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frameCount = steps.reduce(0) { partial, step in
            partial + Int(step.duration * sampleRate)
        }
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        var cursor = 0
        for step in steps {
            let frames = Int(step.duration * sampleRate)
            if frames <= 0 { continue }

            for frame in 0..<frames {
                let progress = Double(frame) / Double(max(frames - 1, 1))
                let fadeIn = min(progress / 0.12, 1)
                let fadeOut = min((1 - progress) / 0.18, 1)
                let envelope = min(fadeIn, fadeOut)
                let t = Double(cursor + frame) / sampleRate
                let sine = sin(2 * .pi * step.frequency * t)
                let harmonic = sin(2 * .pi * step.frequency * 2.03 * t) * 0.18
                let sample = Float((sine + harmonic) * step.amplitude * envelope)
                channel[cursor + frame] = sample
            }
            cursor += frames
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        return buffer
    }

    private func buildPourBuffer(duration: Double) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let resolvedDuration = max(duration, 0.3)
        let frameCount = Int(resolvedDuration * sampleRate)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let channel = buffer.floatChannelData?[0] else {
            return nil
        }

        var randomState: UInt64 = 0xCAFE_BABE
        var lowNoise = 0.0
        var splashNoise = 0.0

        for frame in 0..<frameCount {
            let progress = Double(frame) / Double(max(frameCount - 1, 1))
            let attack = min(progress / 0.08, 1)
            let fillRise = min(progress / 0.84, 1)
            let nearFullFade = progress < 0.88 ? 1 : max(0, (1 - progress) / 0.12)
            let envelope = attack * nearFullFade
            let t = Double(frame) / sampleRate

            let pitchLift = pow(fillRise, 0.85)
            let baseFrequency = 210 + 135 * pitchLift
            let shimmerFrequency = 470 + 250 * pitchLift
            let ripple = sin(2 * .pi * (5.2 + fillRise * 1.8) * t)
            let shimmer = sin(2 * .pi * shimmerFrequency * t + ripple * 0.8)
            let base = sin(2 * .pi * baseFrequency * t + ripple * 0.3)
            let overtone = sin(2 * .pi * (baseFrequency * 1.92) * t)

            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            let white = (Double(randomState & 0xffff) / 32767.5) - 1
            lowNoise = lowNoise * 0.94 + white * 0.06
            splashNoise = splashNoise * 0.72 + (white - lowNoise) * 0.28

            let bodyAmplitude = 0.030 + 0.042 * fillRise
            let sparkleAmplitude = 0.010 + 0.018 * fillRise
            let hissAmplitude = 0.012 + 0.020 * fillRise

            let sample =
                base * bodyAmplitude +
                overtone * bodyAmplitude * 0.34 +
                shimmer * sparkleAmplitude +
                splashNoise * hissAmplitude

            channel[frame] = Float(sample * envelope)
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        return buffer
    }
}
