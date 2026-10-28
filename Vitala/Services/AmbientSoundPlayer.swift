import AVFoundation
import Foundation

/// Calm background sound for mindfulness sessions, synthesised on device —
/// no audio files and nothing to license. A soft spa pad, gentle "ocean"
/// noise that swells with each breath, and optional binaural tones.
@MainActor
final class AmbientSoundPlayer {
    enum Sound: String, CaseIterable, Identifiable {
        case spaBinaural, spa, ocean, silent
        var id: String { rawValue }

        var label: String {
            switch self {
            case .spaBinaural: "Spa & binaural"
            case .spa: "Spa"
            case .ocean: "Ocean"
            case .silent: "Silent"
            }
        }

        var icon: String {
            switch self {
            case .spaBinaural: "headphones"
            case .spa: "sparkles"
            case .ocean: "water.waves"
            case .silent: "speaker.slash.fill"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let synth = AmbientSynth()
    private var stopTask: Task<Void, Never>?
    /// Activating or releasing the audio session can block while the
    /// hardware reconfigures, so it never happens on the main thread. One
    /// serial queue keeps start and stop in the order they were asked for.
    private let audioQueue = DispatchQueue(label: "com.vitala.ambient-audio", qos: .userInitiated)

    /// Starts (or switches to) a sound with a gentle fade-in.
    func play(_ sound: Sound, for category: MindfulnessSession.Category) {
        stopTask?.cancel()
        guard sound != .silent else { stop(); return }
        synth.configure(sound: sound, category: category)
        // The synth fades in from silence, so it can start ramping now.
        synth.targetGain = 1
        audioQueue.async { [engine, synth] in
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setActive(true)
                Self.attachSourceIfNeeded(to: engine, synth: synth)
                if !engine.isRunning { try engine.start() }
            } catch {
                // Sound is a nice-to-have; the session works silently.
            }
        }
    }

    func pause() { synth.targetGain = 0 }

    func resume() { synth.targetGain = 1 }

    /// Follows the breathing guide: the pad and waves swell on the in-breath.
    func setBreath(expanded: Bool) { synth.targetSwell = expanded ? 1 : 0.55 }

    /// Fades out, then releases the audio hardware.
    func stop() {
        synth.targetGain = 0
        stopTask?.cancel()
        stopTask = Task { [engine, audioQueue] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            audioQueue.async {
                engine.stop()
                try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
            }
        }
    }

    /// Runs on `audioQueue`, after the session is active so the output
    /// reports the hardware's sample rate.
    private nonisolated static func attachSourceIfNeeded(to engine: AVAudioEngine, synth: AmbientSynth) {
        guard !engine.attachedNodes.contains(where: { $0 is AVAudioSourceNode }) else { return }
        let output = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = output.sampleRate > 0 ? output.sampleRate : 48_000
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }
        synth.sampleRate = sampleRate
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            synth.render(frames: Int(frameCount), left: left, right: right)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
    }
}

/// Real-time sample generator. Runs on the audio render thread, so it never
/// allocates or locks; parameters are plain values written from the main
/// thread and smoothed per sample.
final class AmbientSynth: @unchecked Sendable {
    var sampleRate: Double = 48_000
    var targetGain: Float = 0
    var targetSwell: Float = 0.75

    private var gain: Float = 0
    private var swell: Float = 0.75

    // Configuration
    /// Four chord tones. A tuple, not an array, so reassigning it from the
    /// main thread never reallocates storage the render thread is reading.
    private var padFreqs: (Double, Double, Double, Double) = (146.83, 220.0, 293.66, 369.99)
    private var padLevel: Float = 0.05
    private var oceanLevel: Float = 0.06
    private var binauralLevel: Float = 0
    private var carrier: Double = 200
    private var beat: Double = 6

    // Oscillator state
    private var padPhases = [Double](repeating: 0, count: 8)
    private var binauralPhases: (Double, Double) = (0, 0)
    private var lfoPhase: Double = 0
    private var wavePhase: Double = 0
    private var noiseSeed: UInt32 = 0x9E3779B9
    private var pink = (b0: Float(0), b1: Float(0), b2: Float(0), b3: Float(0), b4: Float(0), b5: Float(0), b6: Float(0))
    private var lowpass: Float = 0

    func configure(sound: AmbientSoundPlayer.Sound, category: MindfulnessSession.Category) {
        // A different open, consonant chord per category.
        switch category {
        case .sleep:     padFreqs = (110.0, 164.81, 220.0, 277.18)   // A, warm and low
        case .focus:     padFreqs = (130.81, 196.0, 261.63, 329.63)  // C, bright and open
        case .gratitude: padFreqs = (146.83, 220.0, 293.66, 369.99)  // D
        default:         padFreqs = (123.47, 185.0, 246.94, 311.13)  // B
        }
        // Binaural beat frequencies by intent: delta for sleep, theta to
        // settle, alpha for calm focus.
        switch category {
        case .sleep: carrier = 160; beat = 3
        case .breathing, .stress: carrier = 200; beat = 6
        case .focus: carrier = 220; beat = 10
        case .gratitude: carrier = 210; beat = 8
        }
        switch sound {
        case .spaBinaural: padLevel = 0.045; oceanLevel = 0.05; binauralLevel = 0.05
        case .spa:         padLevel = 0.05;  oceanLevel = 0.06; binauralLevel = 0
        case .ocean:       padLevel = 0;     oceanLevel = 0.11; binauralLevel = 0
        case .silent:      padLevel = 0;     oceanLevel = 0;    binauralLevel = 0
        }
    }

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        let sr = sampleRate
        let twoPi = 2 * Double.pi
        let freqs = padFreqs
        for i in 0..<frames {
            // Smooth parameter changes (≈1.5 s fades, ≈1 s swells).
            gain += (targetGain - gain) * Float(1 / (sr * 0.5))
            swell += (targetSwell - swell) * Float(1 / (sr * 0.35))

            // Slow LFO for a breathing shimmer in the pad.
            lfoPhase += 0.07 / sr
            if lfoPhase >= 1 { lfoPhase -= 1 }
            let lfo = Float(0.85 + 0.15 * sin(twoPi * lfoPhase))

            // Pad: each note is two slightly detuned sines (chorus) plus a soft octave.
            var pad: Float = 0
            for n in 0..<4 {
                let f: Double
                switch n {
                case 0: f = freqs.0
                case 1: f = freqs.1
                case 2: f = freqs.2
                default: f = freqs.3
                }
                let a = n * 2, b = n * 2 + 1
                padPhases[a] += f / sr
                padPhases[b] += (f * 1.0021) / sr
                if padPhases[a] >= 1 { padPhases[a] -= 1 }
                if padPhases[b] >= 1 { padPhases[b] -= 1 }
                pad += Float(sin(twoPi * padPhases[a]) + sin(twoPi * padPhases[b]) * 0.8
                             + sin(4 * Double.pi * padPhases[a]) * 0.15)
            }
            pad *= padLevel * lfo * (0.7 + 0.3 * swell)

            // Ocean: pink noise, low-passed, swelling slowly like waves.
            noiseSeed ^= noiseSeed << 13; noiseSeed ^= noiseSeed >> 17; noiseSeed ^= noiseSeed << 5
            let white = Float(Int32(bitPattern: noiseSeed)) / Float(Int32.max)
            pink.b0 = 0.99886 * pink.b0 + white * 0.0555179
            pink.b1 = 0.99332 * pink.b1 + white * 0.0750759
            pink.b2 = 0.96900 * pink.b2 + white * 0.1538520
            pink.b3 = 0.86650 * pink.b3 + white * 0.3104856
            pink.b4 = 0.55000 * pink.b4 + white * 0.5329522
            pink.b5 = -0.7616 * pink.b5 - white * 0.0168980
            let pinkSample = (pink.b0 + pink.b1 + pink.b2 + pink.b3 + pink.b4 + pink.b5 + pink.b6 + white * 0.5362) * 0.11
            pink.b6 = white * 0.115926
            lowpass += (pinkSample - lowpass) * 0.08
            wavePhase += 0.09 / sr
            if wavePhase >= 1 { wavePhase -= 1 }
            let wave = Float(0.55 + 0.45 * sin(twoPi * wavePhase))
            let ocean = lowpass * oceanLevel * 6 * wave * (0.6 + 0.4 * swell)

            // Binaural: a slightly different pure tone in each ear.
            binauralPhases.0 += carrier / sr
            binauralPhases.1 += (carrier + beat) / sr
            if binauralPhases.0 >= 1 { binauralPhases.0 -= 1 }
            if binauralPhases.1 >= 1 { binauralPhases.1 -= 1 }
            let bl = Float(sin(twoPi * binauralPhases.0)) * binauralLevel
            let br = Float(sin(twoPi * binauralPhases.1)) * binauralLevel

            left[i] = (pad + ocean + bl) * gain
            right[i] = (pad + ocean * 0.92 + br) * gain
        }
    }
}
