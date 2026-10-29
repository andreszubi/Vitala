import CoreHaptics
import Foundation

/// Haptic guidance for the breathing player. Through each in-breath a soft
/// swell rises under taps that grow stronger; through each out-breath both
/// fade and the taps slow; a hold gets one light tap, then stillness.
@MainActor
final class BreathHaptics {
    /// One moment of feedback, in seconds from the start of what's played.
    struct Pulse: Equatable {
        enum Kind { case tap, swell }
        var kind: Kind
        var time: Double
        /// Only for a swell: how long it lasts.
        var duration: Double = 0
        var intensity: Float
        var sharpness: Float
    }

    static let storageKey = "vitala.breathingHaptics"

    private var engine: CHHapticEngine?
    private var engineRunning = false
    private var player: CHHapticPatternPlayer?
    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    /// Plays guidance for the rest of a breathing phase, starting `from`
    /// seconds into a phase `length` seconds long.
    func play(_ kind: MindfulnessSession.BreathStep.Kind, from: Double, length: Double) {
        stop()
        guard supported, let engine = runningEngine() else { return }
        let events = Self.pulses(kind, from: from, length: length).map(Self.event)
        guard !events.isEmpty,
              let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
        self.player = player
    }

    /// Stops the current phase's guidance, e.g. on pause.
    func stop() {
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
    }

    /// Releases the haptic hardware when the session ends.
    func shutDown() {
        stop()
        engine?.stop()
        engine = nil
        engineRunning = false
    }

    private func runningEngine() -> CHHapticEngine? {
        if engine == nil {
            guard let created = try? CHHapticEngine() else { return nil }
            created.playsHapticsOnly = true
            // The system stops the engine in the background or after an
            // interruption; start it again before the next phase.
            created.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engineRunning = false }
            }
            created.resetHandler = { [weak self] in
                Task { @MainActor in self?.engineRunning = false }
            }
            engine = created
        }
        if !engineRunning {
            do {
                try engine?.start()
                engineRunning = true
            } catch {
                return nil
            }
        }
        return engine
    }

    // MARK: Patterns

    /// The feedback for the part of a phase still to come. Pure, so it can
    /// be tested without haptic hardware.
    nonisolated static func pulses(_ kind: MindfulnessSession.BreathStep.Kind,
                                   from: Double, length: Double) -> [Pulse] {
        guard length > 0, from < length else { return [] }
        var all: [Pulse] = []
        switch kind {
        case .inhale:
            // Taps every half second, rising from soft to firm.
            for t in stride(from: 0, to: length - 0.2, by: 0.5) {
                let p = Float(t / length)
                all.append(Pulse(kind: .tap, time: t, intensity: 0.3 + 0.55 * p, sharpness: 0.2 + 0.25 * p))
            }
            all += swell(length: length, from: 0.08, to: 0.32)
        case .exhale:
            // Taps a little further apart, fading as the breath empties.
            for t in stride(from: 0, to: length - 0.2, by: 0.6) {
                let p = Float(t / length)
                all.append(Pulse(kind: .tap, time: t, intensity: 0.75 - 0.6 * p, sharpness: 0.35 - 0.25 * p))
            }
            all += swell(length: length, from: 0.32, to: 0.04)
        case .hold:
            all.append(Pulse(kind: .tap, time: 0, intensity: 0.35, sharpness: 0.1))
        }
        // Skip what has already passed, and time the rest from now.
        return all.compactMap { pulse in
            if pulse.kind == .tap {
                guard pulse.time >= from - 0.05 else { return nil }
                var shifted = pulse
                shifted.time = max(0, pulse.time - from)
                return shifted
            }
            let end = pulse.time + pulse.duration
            guard end > from else { return nil }
            var shifted = pulse
            shifted.time = max(0, pulse.time - from)
            shifted.duration = end - max(pulse.time, from)
            return shifted
        }
        .sorted { $0.time < $1.time }
    }

    /// A soft, low vibration rising or falling across the phase, as short
    /// back-to-back segments so its strength can change smoothly.
    private nonisolated static func swell(length: Double, from start: Float, to end: Float) -> [Pulse] {
        let step = 0.5
        return stride(from: 0, to: length, by: step).map { t in
            let p = Float(min(1, (t + step / 2) / length))
            return Pulse(kind: .swell, time: t, duration: min(step, length - t),
                         intensity: start + (end - start) * p, sharpness: 0.05)
        }
    }

    private nonisolated static func event(_ pulse: Pulse) -> CHHapticEvent {
        let parameters = [CHHapticEventParameter(parameterID: .hapticIntensity, value: pulse.intensity),
                          CHHapticEventParameter(parameterID: .hapticSharpness, value: pulse.sharpness)]
        switch pulse.kind {
        case .tap:
            return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: pulse.time)
        case .swell:
            return CHHapticEvent(eventType: .hapticContinuous, parameters: parameters,
                                 relativeTime: pulse.time, duration: pulse.duration)
        }
    }
}
