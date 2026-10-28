import Testing
@testable import Vitala

struct ZenSceneTests {
    @Test func matchSessionPicksASceneForEveryCategory() {
        let scenes = MindfulnessSession.Category.allCases.map { ZenScene.automatic.resolved(for: $0) }
        #expect(!scenes.contains(.automatic) && !scenes.contains(.off))
        #expect(Set(scenes).count == scenes.count, "each kind of session gets its own scene")
    }

    @Test func aChosenSceneIsKeptWhateverTheSession() {
        for category in MindfulnessSession.Category.allCases {
            #expect(ZenScene.rain.resolved(for: category) == .rain)
            #expect(ZenScene.off.resolved(for: category) == .off)
        }
    }

    @Test func pseudoRandomPlacementIsStableAndInRange() {
        for a in 0..<50 {
            for b in 0..<5 {
                let value = ZenPainter.hash(a, b)
                #expect(value >= 0 && value < 1)
                #expect(value == ZenPainter.hash(a, b))
            }
        }
    }
}
