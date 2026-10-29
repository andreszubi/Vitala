import AVFoundation
import Foundation
import Testing
@testable import Vitala

struct AmbientSoundTests {
    private func render(_ sound: AmbientSoundPlayer.Sound, _ category: MindfulnessSession.Category,
                        seconds: Double, sampleRate: Double = 48_000) -> (left: [Float], right: [Float]) {
        let synth = AmbientSynth()
        synth.sampleRate = sampleRate
        synth.configure(sound: sound, category: category)
        synth.targetGain = 1
        let total = Int(seconds * sampleRate)
        var left = [Float](repeating: 0, count: total)
        var right = [Float](repeating: 0, count: total)
        let chunk = 512
        var offset = 0
        while offset < total {
            let n = min(chunk, total - offset)
            // Breathe: swell every 4 seconds, like the guide.
            synth.targetSwell = (Int(Double(offset) / sampleRate) / 4) % 2 == 0 ? 1 : 0.55
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    synth.render(frames: n, left: l.baseAddress! + offset, right: r.baseAddress! + offset)
                }
            }
            offset += n
        }
        return (left, right)
    }

    private func rms(_ x: ArraySlice<Float>) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }

    @Test func spaAndBinauralIsAudibleCleanAndStereo() {
        let (l, r) = render(.spaBinaural, .stress, seconds: 6)
        #expect(l.allSatisfy { $0.isFinite } && r.allSatisfy { $0.isFinite })
        #expect((l + r).map(abs).max()! < 1.0, "must never clip")
        let tail = l.count / 2
        #expect(rms(l[tail...]) > 0.02, "audible once faded in")
        #expect(zip(l[tail...], r[tail...]).contains { abs($0 - $1) > 0.01 }, "binaural differs per ear")
    }

    /// Spa & binaural must sound clearly different from Spa, not just
    /// measure differently: the binaural tones need to stand out over the
    /// pad rather than hide inside it.
    @Test func binauralIsClearlyDifferentFromSpa() {
        for category in MindfulnessSession.Category.allCases {
            let spa = render(.spa, category, seconds: 6)
            let binaural = render(.spaBinaural, category, seconds: 6)
            let tail = spa.left.count / 2
            let difference = zip(binaural.left[tail...], spa.left[tail...]).map { $0 - $1 }
            let ratio = rms(difference[...]) / rms(spa.left[tail...])
            #expect(ratio > 0.6, "\(category): binaural layer is too quiet to hear (\(ratio))")
        }
    }

    @Test func crystalBowlsRingAndStayDistinct() {
        let bowls = render(.crystalBowls, .breathing, seconds: 10)
        let spa = render(.spa, .breathing, seconds: 10)
        #expect(bowls.left.allSatisfy { $0.isFinite } && bowls.right.allSatisfy { $0.isFinite })
        #expect((bowls.left + bowls.right).map(abs).max()! < 1.0, "must never clip")
        let tail = bowls.left.count / 2
        #expect(rms(bowls.left[tail...]) > 0.02, "audible once faded in")
        let difference = zip(bowls.left[tail...], spa.left[tail...]).map { $0 - $1 }
        #expect(rms(difference[...]) / rms(spa.left[tail...]) > 0.6, "sounds different from Spa")
        // Bowls are struck: the level swells after a strike and decays between strikes.
        let window = 4_800
        let levels = stride(from: 0, to: bowls.left.count - window, by: window).map { rms(bowls.left[$0..<($0 + window)]) }
        #expect(levels.max()! > levels[(levels.count / 2)...].min()! * 1.15, "struck, not a flat drone")
    }

    @Test func combinedMixHasEveryLayerAndNeverClips() {
        let mix = render(.spaBinauralBowls, .breathing, seconds: 16)
        #expect(mix.left.allSatisfy { $0.isFinite } && mix.right.allSatisfy { $0.isFinite })
        #expect((mix.left + mix.right).map(abs).max()! < 1.0, "must never clip, even with bowls overlapping")
        let tail = mix.left.count / 2
        #expect(zip(mix.left[tail...], mix.right[tail...]).contains { abs($0 - $1) > 0.01 }, "binaural differs per ear")
        for other in [AmbientSoundPlayer.Sound.spa, .spaBinaural, .crystalBowls] {
            let alone = render(other, .breathing, seconds: 16)
            let difference = zip(mix.left[tail...], alone.left[tail...]).map { $0 - $1 }
            #expect(rms(difference[...]) / rms(alone.left[tail...]) > 0.3, "the mix differs from \(other)")
        }
    }

    @Test func fadesInGently() {
        let (l, _) = render(.spa, .sleep, seconds: 3)
        #expect(rms(l[0..<480]) < rms(l[(l.count - 4800)...]) * 0.2, "first 10 ms is near-silent")
    }

    @Test func silentProducesSilence() {
        let (l, r) = render(.silent, .focus, seconds: 1)
        #expect(l.allSatisfy { $0 == 0 } && r.allSatisfy { $0 == 0 })
    }

    /// Writes a short preview so the sound can be auditioned outside the app.
    @Test func writesPreviewSample() throws {
        let sampleRate = 44_100.0
        let (l, r) = render(.spaBinaural, .breathing, seconds: 20, sampleRate: sampleRate)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(l.count)))
        buffer.frameLength = AVAudioFrameCount(l.count)
        for i in 0..<l.count {
            buffer.floatChannelData![0][i] = l[i]
            buffer.floatChannelData![1][i] = r[i]
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("vitala-ambient-preview.caf")
        try? FileManager.default.removeItem(at: url)
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        print("AMBIENT_PREVIEW \(url.path)")
    }
}
