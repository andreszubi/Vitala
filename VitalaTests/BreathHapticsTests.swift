import Testing
@testable import Vitala

struct BreathHapticsTests {
    private func taps(_ pulses: [BreathHaptics.Pulse]) -> [BreathHaptics.Pulse] {
        pulses.filter { $0.kind == .tap }
    }
    private func swell(_ pulses: [BreathHaptics.Pulse]) -> [BreathHaptics.Pulse] {
        pulses.filter { $0.kind == .swell }
    }

    @Test func inhaleTapsGrowStrongerUnderARisingSwell() {
        let pulses = BreathHaptics.pulses(.inhale, from: 0, length: 4)
        let t = taps(pulses)
        #expect(t.count == 8)                                   // every 0.5 s
        #expect(zip(t, t.dropFirst()).allSatisfy { $0.intensity < $1.intensity })
        let s = swell(pulses)
        #expect(s.first!.intensity < s.last!.intensity)
        #expect(abs(s.reduce(0) { $0 + $1.duration } - 4) < 0.001, "the swell spans the whole breath")
    }

    @Test func exhaleTapsFadeAndSlow() {
        let pulses = BreathHaptics.pulses(.exhale, from: 0, length: 8)
        let t = taps(pulses)
        #expect(zip(t, t.dropFirst()).allSatisfy { $0.intensity > $1.intensity })
        #expect(abs(t[1].time - t[0].time - 0.6) < 0.001, "further apart than the in-breath")
        let s = swell(pulses)
        #expect(s.first!.intensity > s.last!.intensity)
    }

    @Test func holdIsOneLightTap() {
        let pulses = BreathHaptics.pulses(.hold, from: 0, length: 7)
        #expect(pulses.count == 1)
        #expect(pulses[0].kind == .tap && pulses[0].intensity < 0.5)
        // Rejoining a hold partway through stays still.
        #expect(BreathHaptics.pulses(.hold, from: 3, length: 7).isEmpty)
    }

    @Test func resumingMidBreathPlaysOnlyWhatIsLeft() {
        let full = taps(BreathHaptics.pulses(.inhale, from: 0, length: 4))
        let rest = BreathHaptics.pulses(.inhale, from: 2.2, length: 4)
        let restTaps = taps(rest)
        #expect(restTaps.count == full.filter { $0.time >= 2.15 }.count)
        #expect(restTaps.first!.time >= 0 && restTaps.first!.time < 0.5)
        // Strength carries on from where the breath was, not from the start.
        #expect(restTaps.first!.intensity > full.first!.intensity)
        #expect(abs(swell(rest).reduce(0) { $0 + $1.duration } - 1.8) < 0.001)
        #expect(BreathHaptics.pulses(.inhale, from: 4, length: 4).isEmpty)
    }

    @Test func strengthsStayInRange() {
        for kind in [MindfulnessSession.BreathStep.Kind.inhale, .exhale, .hold] {
            for length in [4.0, 6.0, 7.0, 8.0] {
                for pulse in BreathHaptics.pulses(kind, from: 0, length: length) {
                    #expect((0...1).contains(pulse.intensity) && (0...1).contains(pulse.sharpness))
                    #expect(pulse.time >= 0 && pulse.time + pulse.duration <= length + 0.001)
                }
            }
        }
    }
}
