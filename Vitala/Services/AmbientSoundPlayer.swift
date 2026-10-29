import AVFoundation
import Foundation

/// Calm background sound for mindfulness sessions, synthesised on device —
/// no audio files and nothing to license. A soft spa pad, gentle "ocean"
/// noise that swells with each breath, and optional binaural tones.
@MainActor
final class AmbientSoundPlayer {
    enum Sound: String, CaseIterable, Identifiable {
        // Menu order.
        case spaBinauralBowls, spaBinaural, spa, crystalBowls, ocean, silent
        var id: String { rawValue }

        /// The session's current sound, shared by the player and its menu.
        /// Reset to `defaultSound` whenever a session starts.
        static let storageKey = "vitala.ambientSound"
        static let defaultSound: Sound = .spaBinauralBowls

        var label: String {
            switch self {
            case .spaBinaural: "Spa & binaural"
            case .crystalBowls: "Crystal bowls"
            case .spaBinauralBowls: "Spa, binaural & bowls"
            case .spa: "Spa"
            case .ocean: "Ocean"
            case .silent: "Silent"
            }
        }

        /// Plays a slightly different tone in each ear; best with headphones.
        var usesBinaural: Bool { self == .spaBinaural || self == .spaBinauralBowls }

        var icon: String {
            switch self {
            case .spaBinaural: "headphones"
            case .crystalBowls: "bell.fill"
            case .spaBinauralBowls: "square.stack.3d.up.fill"
            case .spa: "sparkles"
            case .ocean: "water.waves"
            case .silent: "speaker.slash.fill"
            }
        }
    }

    private let engine = AVAudioEngine()
    private let synth = AmbientSynth()
    private var stopTask: Task<Void, Never>?
    /// Whether this player is currently counted as using the audio session.
    private let lease = AudioSessionLease()

    /// Starts (or switches to) a sound with a gentle fade-in.
    func play(_ sound: Sound, for category: MindfulnessSession.Category) {
        stopTask?.cancel()
        guard sound != .silent else { stop(); return }
        synth.configure(sound: sound, category: category)
        // The synth fades in from silence, so it can start ramping now.
        synth.targetGain = 1
        Self.audioQueue.async { [engine, synth, lease] in
            do {
                try Self.acquireSession(lease)
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
        stopTask = Task { [engine, lease] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard !Task.isCancelled else { return }
            Self.audioQueue.async {
                engine.stop()
                Self.releaseSession(lease)
            }
        }
    }

    // MARK: Audio session

    /// Activating or releasing the audio session can block while the
    /// hardware reconfigures, so it never happens on the main thread. One
    /// queue shared by every player keeps starts and stops in the order they
    /// were asked for, including a session that closes just as another opens.
    private static let audioQueue = DispatchQueue(label: "com.vitala.ambient-audio", qos: .userInitiated)
    /// Players currently using the session. Touched only on `audioQueue`.
    nonisolated(unsafe) private static var activePlayers = 0

    /// Runs on `audioQueue`. Configures and activates the session only when
    /// it isn't already set up, so starting a sound never re-routes audio
    /// that is already playing.
    private nonisolated static func acquireSession(_ lease: AudioSessionLease) throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback || !session.categoryOptions.contains(.mixWithOthers) {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        guard !lease.held else { return }
        if activePlayers == 0 { try session.setActive(true) }
        activePlayers += 1
        lease.held = true
    }

    /// Runs on `audioQueue`. Lets go of the session once no player needs it,
    /// so a session closing never silences one that has just started.
    private nonisolated static func releaseSession(_ lease: AudioSessionLease) {
        guard lease.held else { return }
        lease.held = false
        activePlayers -= 1
        if activePlayers == 0 {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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

/// Whether one player holds the shared audio session. Read and written only
/// on the players' shared audio queue.
private final class AudioSessionLease: @unchecked Sendable {
    var held = false
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

    // Crystal singing bowls: three struck bowls tuned to the session's chord,
    // plus one bowl "sung" continuously underneath.
    private var bowlLevel: Float = 0
    private var bowlFreqs: (Double, Double, Double) = (440.0, 587.33, 739.99)
    private var singingFreq: Double = 293.66
    /// Per bowl: strike energy (decays slowly) and the smoothed envelope that
    /// follows it, which softens the mallet's attack.
    private var bowlStrike: (Float, Float, Float) = (0, 0, 0)
    private var bowlEnv: (Float, Float, Float) = (0, 0, 0)
    /// Four partials per struck bowl, then two for the singing bowl.
    private var bowlPhases = [Double](repeating: 0, count: 14)
    private var samplesSinceStrike = 0
    private var strikeCount = 0

    func configure(sound: AmbientSoundPlayer.Sound, category: MindfulnessSession.Category) {
        // A different open, consonant chord per category.
        switch category {
        case .sleep:     padFreqs = (110.0, 164.81, 220.0, 277.18)   // A, warm and low
        case .focus:     padFreqs = (130.81, 196.0, 261.63, 329.63)  // C, bright and open
        case .gratitude: padFreqs = (146.83, 220.0, 293.66, 369.99)  // D
        default:         padFreqs = (123.47, 185.0, 246.94, 311.13)  // B
        }
        // Binaural beat frequencies by intent: delta for sleep, theta to
        // settle, alpha for calm focus. The carrier is the fifth of the
        // pad's chord, an octave up: above the pad so it isn't masked, in
        // tune with it, and high enough for iPhone speakers to play.
        switch category {
        case .sleep: carrier = 329.63; beat = 3       // E over A
        case .breathing, .stress: carrier = 369.99; beat = 6 // F♯ over B
        case .focus: carrier = 392.0; beat = 10       // G over C
        case .gratitude: carrier = 440.0; beat = 8    // A over D
        }
        switch sound {
        case .spaBinaural: padLevel = 0.04;  oceanLevel = 0.04; binauralLevel = 0.09
        case .spa:         padLevel = 0.05;  oceanLevel = 0.06; binauralLevel = 0
        // A quiet pad underneath so the bowls ring out over warmth, not silence.
        case .crystalBowls: padLevel = 0.018; oceanLevel = 0;   binauralLevel = 0
        // Everything together, each layer pulled back so the mix stays calm.
        case .spaBinauralBowls: padLevel = 0.032; oceanLevel = 0.032; binauralLevel = 0.07
        case .ocean:       padLevel = 0;     oceanLevel = 0.11; binauralLevel = 0
        case .silent:      padLevel = 0;     oceanLevel = 0;    binauralLevel = 0
        }
        switch sound {
        case .crystalBowls: bowlLevel = 0.11
        case .spaBinauralBowls: bowlLevel = 0.085
        default: bowlLevel = 0
        }
        // The bowls sit an octave above the pad's chord tones.
        switch category {
        case .sleep:     bowlFreqs = (329.63, 440.0, 554.37); singingFreq = 220.0
        case .focus:     bowlFreqs = (392.0, 523.25, 659.26); singingFreq = 261.63
        case .gratitude: bowlFreqs = (440.0, 587.33, 739.99); singingFreq = 293.66
        default:         bowlFreqs = (370.0, 493.88, 622.25); singingFreq = 246.94
        }
    }

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        let sr = sampleRate
        let twoPi = 2 * Double.pi
        let freqs = padFreqs
        let bowls = bowlFreqs
        // A struck crystal bowl rings for a long time; overtones fade sooner.
        let ring = Float(exp(-1 / (sr * 9)))
        let mallet = Float(1 / (sr * 0.04))
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

            // Crystal bowls.
            var bowlL: Float = 0, bowlR: Float = 0
            if bowlLevel > 0 {
                samplesSinceStrike += 1
                // Strikes 6.5–8 s apart, never quite regular; the first comes after a second.
                let gap = strikeCount == 0 ? 1.0 : 6.5 + 0.75 * Double((strikeCount * 2) % 3)
                if Double(samplesSinceStrike) >= gap * sr {
                    samplesSinceStrike = 0
                    switch strikeCount % 3 {
                    case 0: bowlStrike.0 = 1
                    case 1: bowlStrike.1 = 1
                    default: bowlStrike.2 = 1
                    }
                    strikeCount += 1
                }
                bowlStrike.0 *= ring; bowlStrike.1 *= ring; bowlStrike.2 *= ring
                bowlEnv.0 += (bowlStrike.0 - bowlEnv.0) * mallet
                bowlEnv.1 += (bowlStrike.1 - bowlEnv.1) * mallet
                bowlEnv.2 += (bowlStrike.2 - bowlEnv.2) * mallet
                for b in 0..<3 {
                    let f: Double, env: Float, panL: Float, panR: Float
                    switch b {
                    case 0: f = bowls.0; env = bowlEnv.0; panL = 0.75; panR = 0.75
                    case 1: f = bowls.1; env = bowlEnv.1; panL = 0.95; panR = 0.5
                    default: f = bowls.2; env = bowlEnv.2; panL = 0.5; panR = 0.95
                    }
                    guard env > 0.0005 else { continue }
                    let base = b * 4
                    // Two nearly equal partials beat slowly, the bowl's shimmer;
                    // faint inharmonic overtones fade faster (env squared).
                    let ratios = (1.0, 1.0035, 2.76, 5.4)
                    bowlPhases[base] += f * ratios.0 / sr
                    bowlPhases[base + 1] += f * ratios.1 / sr
                    bowlPhases[base + 2] += f * ratios.2 / sr
                    bowlPhases[base + 3] += f * ratios.3 / sr
                    for k in base..<(base + 4) where bowlPhases[k] >= 1 { bowlPhases[k] -= 1 }
                    let body = Float(sin(twoPi * bowlPhases[base]) + 0.7 * sin(twoPi * bowlPhases[base + 1]))
                    let overtones = Float(0.16 * sin(twoPi * bowlPhases[base + 2]) + 0.05 * sin(twoPi * bowlPhases[base + 3]))
                    let v = (body * env + overtones * env * env) * bowlLevel
                    bowlL += v * panL
                    bowlR += v * panR
                }
                // The singing bowl, swelling with the breath.
                bowlPhases[12] += singingFreq / sr
                bowlPhases[13] += singingFreq * 1.002 / sr
                if bowlPhases[12] >= 1 { bowlPhases[12] -= 1 }
                if bowlPhases[13] >= 1 { bowlPhases[13] -= 1 }
                let sing = Float(sin(twoPi * bowlPhases[12]) + 0.6 * sin(twoPi * bowlPhases[13]))
                    * bowlLevel * 0.35 * (0.45 + 0.55 * swell)
                bowlL += sing
                bowlR += sing
            }

            left[i] = (pad + ocean + bl + bowlL) * gain
            right[i] = (pad + ocean * 0.92 + br + bowlR) * gain
        }
    }
}
