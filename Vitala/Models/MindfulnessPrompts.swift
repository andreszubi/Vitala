import Foundation

// Gentle cues shown under the breathing guide. Each kind of session has its
// own pool, and some sessions add lines of their own; the player shuffles
// them so every session reads differently.

extension MindfulnessSession.Category {
    var prompts: [String] {
        switch self {
        case .breathing:
            [
                "Let your shoulders drop.",
                "Breathe in through your nose.",
                "Nothing to fix. Just breathe.",
                "Feel the air, cool on the way in.",
                "Let your belly rise before your chest.",
                "Unclench your jaw.",
                "Each breath is a fresh start.",
                "Let the circle set the pace.",
                "Notice the pause between breaths.",
                "Soften your hands.",
                "Breathe in as if smelling a flower.",
                "Let the exhale leave on its own.",
                "Your breath is always here to come back to.",
                "Slow is the whole point.",
            ]
        case .focus:
            [
                "Name the one thing you'll do next.",
                "Notice where your attention goes, then return.",
                "Soften your jaw and eyes.",
                "When a thought pulls you away, simply come back.",
                "Let other tasks wait their turn.",
                "One breath, one thing.",
                "Feel your feet on the floor.",
                "Clear the desk in your mind.",
                "Attention grows with practice. This is practice.",
                "Rest your gaze on one point.",
                "Drifting isn't failing. Returning is the skill.",
                "Breathe in clarity, breathe out clutter.",
                "Picture the first small step.",
                "Arrive here before you begin.",
            ]
        case .sleep:
            [
                "Let the day go, one breath at a time.",
                "Feel the weight of your body resting.",
                "Long, slow exhale.",
                "Your bed is holding you. You can let go.",
                "There's nothing left to do tonight.",
                "Let your eyelids grow heavy.",
                "Each exhale sinks you a little deeper.",
                "Thoughts can wait until morning.",
                "Relax the muscles around your eyes.",
                "Let your breath grow quiet and slow.",
                "Feel the warmth around you.",
                "Release your hands, your arms, your shoulders.",
                "Drift. Don't try.",
                "Rest is enough for now.",
            ]
        case .stress:
            [
                "Scan from your forehead down to your feet.",
                "Wherever you feel tension, breathe into it.",
                "Your exhale is longer than your inhale.",
                "Drop your shoulders away from your ears.",
                "This feeling will pass.",
                "You're safe in this moment.",
                "Loosen your grip on what you can't control.",
                "Let each exhale carry some tension out.",
                "Unclench your hands.",
                "One breath at a time is enough.",
                "Notice the ground supporting you.",
                "Slow breath, calmer body.",
                "You don't have to solve it right now.",
                "Be as kind to yourself as you would be to a friend.",
            ]
        case .gratitude:
            [
                "Think of someone who made today easier.",
                "Recall a small moment that felt good.",
                "What's one thing you're glad you have?",
                "Picture a place that feels like home.",
                "Thank your body for carrying you today.",
                "Notice something beautiful nearby.",
                "Remember a kindness you received.",
                "Who would you like to thank?",
                "Think of a skill you're glad to have.",
                "Savour a favourite meal from memory.",
                "Recall the last time you laughed.",
                "Appreciate this breath, right now.",
                "What are you looking forward to?",
                "Let a warm feeling spread with each breath.",
            ]
        }
    }
}

extension MindfulnessSession {
    /// The category's cues plus any written for this session.
    var prompts: [String] {
        category.prompts + (MindfulnessLibrary.sessionPrompts[title] ?? [])
    }
}

extension MindfulnessLibrary {
    /// Lines that only make sense for one session, by title.
    static let sessionPrompts: [String: [String]] = [
        "Quick reset": [
            "One minute is enough to reset.",
            "Step out of the rush for a moment.",
            "Come back to now.",
            "The next task can wait a minute.",
        ],
        "Box breathing": [
            "Four sides: in, hold, out, hold.",
            "Trace a square with your breath.",
            "Keep every side the same length.",
            "Steady, like the corners of a box.",
        ],
        "Morning intention": [
            "How do you want today to feel?",
            "Choose one word for today.",
            "What would make today a good day?",
            "Let the morning be unhurried.",
            "Greet the day with an easy breath.",
        ],
        "Focus before deep work": [
            "Put your phone out of reach.",
            "Picture the work going well.",
            "Decide what done looks like.",
            "Settle in, then begin.",
            "The next hour is yours.",
        ],
        "4-7-8 for sleep": [
            "In for four, hold for seven, out for eight.",
            "Let the long exhale slow your heart.",
            "Hold gently. Don't strain.",
            "Breathe out through your mouth, slow and soft.",
        ],
        "Wind-down for sleep": [
            "Put today's to-do list down.",
            "Name one thing that went well today.",
            "The day is done. You did enough.",
            "Let tomorrow look after itself.",
        ],
        "Stress reset": [
            "Make each exhale a little longer.",
            "Sigh it out if you need to.",
            "Let your heart rate settle.",
            "Pause before you respond.",
        ],
        "Body scan": [
            "Bring your attention to your scalp and forehead.",
            "Soften your face, your jaw, your tongue.",
            "Let your neck and shoulders melt.",
            "Feel your arms grow heavy.",
            "Breathe into your chest and belly.",
            "Relax your hips and legs.",
            "Notice your feet, then let them rest.",
        ],
        "Three good things": [
            "Name the first good thing from today.",
            "Now a second, however small.",
            "And a third. Let it linger.",
            "Why did those good things happen?",
        ],
    ]
}

/// The order cues appear in during one session: shuffled, every cue once
/// before any repeats, and never opening on the cue the last session of the
/// same kind opened on.
enum PromptDeck {
    @MainActor private static var lastOpening: [String: String] = [:]

    @MainActor
    static func deal(for session: MindfulnessSession) -> [String] {
        let key = session.category.rawValue
        let order = shuffled(session.prompts, avoidingFirst: lastOpening[key])
        lastOpening[key] = order.first
        return order
    }

    static func shuffled<G: RandomNumberGenerator>(_ prompts: [String], avoidingFirst avoid: String?,
                                                   using generator: inout G) -> [String] {
        var order = prompts.shuffled(using: &generator)
        if order.count > 1, let avoid, order.first == avoid {
            order.swapAt(0, Int.random(in: 1..<order.count, using: &generator))
        }
        return order
    }

    static func shuffled(_ prompts: [String], avoidingFirst avoid: String?) -> [String] {
        var generator = SystemRandomNumberGenerator()
        return shuffled(prompts, avoidingFirst: avoid, using: &generator)
    }
}
