import Testing
@testable import Vitala

struct MindfulnessPromptTests {
    @Test func everyKindOfSessionHasPlentyOfItsOwnCues() {
        for category in MindfulnessSession.Category.allCases {
            let prompts = category.prompts
            #expect(prompts.count >= 12, "\(category)")
            #expect(Set(prompts).count == prompts.count, "\(category) has duplicates")
        }
        let all = MindfulnessSession.Category.allCases.flatMap(\.prompts)
        #expect(Set(all).count == all.count, "each cue belongs to one kind of session")
    }

    @Test func sessionsAddTheirOwnLinesAndEveryLineFits() {
        for session in MindfulnessLibrary.all {
            #expect(MindfulnessLibrary.sessionPrompts[session.title] != nil, "\(session.title) has its own lines")
            #expect(Set(session.prompts).count == session.prompts.count, "\(session.title) has duplicates")
            for line in session.prompts {
                #expect(!line.isEmpty && line.count <= 60, "\"\(line)\" should fit in two short lines")
            }
        }
        // Every session title in the extras exists, so none is silently unused.
        let titles = Set(MindfulnessLibrary.all.map(\.title))
        #expect(Set(MindfulnessLibrary.sessionPrompts.keys).isSubset(of: titles))
    }

    @Test func dealingShufflesWithoutLosingOrRepeatingCues() {
        let prompts = MindfulnessLibrary.quickReset.prompts
        let order = PromptDeck.shuffled(prompts, avoidingFirst: nil)
        #expect(order.sorted() == prompts.sorted())
        // Over many deals the opening cue varies.
        let openings = Set((0..<40).map { _ in PromptDeck.shuffled(prompts, avoidingFirst: nil).first! })
        #expect(openings.count > 5)
    }

    @Test func neverOpensOnTheLastSessionsOpeningCue() {
        let prompts = MindfulnessLibrary.all[4].prompts
        for _ in 0..<200 {
            let order = PromptDeck.shuffled(prompts, avoidingFirst: prompts[0])
            #expect(order.first != prompts[0])
            #expect(order.count == prompts.count)
        }
    }
}
