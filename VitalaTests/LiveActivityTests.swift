import Foundation
import Testing
@testable import Vitala

struct LiveActivityTests {
    typealias State = SessionActivityAttributes.ContentState
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aRunningWorkoutCountsUpFromItsStart() {
        let state = State.workout(exercise: "Push-up", index: 1, count: 4, prescription: "3 × 10 reps",
                                  elapsed: 125, isRunning: true, now: now)
        #expect(state.title == "Push-up")
        #expect(state.detail == "3 × 10 reps")
        #expect(state.position == 2 && state.count == 4)
        // Counting up from two minutes five seconds ago reads 2:05 now.
        #expect(state.clock == .up(from: now.addingTimeInterval(-125)))
        #expect(state.step == nil, "an exercise counted in reps has nothing to count down")
        #expect(!state.isPaused && !state.isFinished && state.breath == nil)
    }

    @Test func aTimedExerciseShowsHowFarThroughItIs() {
        let state = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "3 × 30 sec",
                                  elapsed: 20, stepElapsed: 20, stepLength: 90, isRunning: true, now: now)
        #expect(state.step == .init(start: now.addingTimeInterval(-20), end: now.addingTimeInterval(70)))
        // An exercise already past its time ends now, never in the past.
        let late = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "30 sec",
                                 elapsed: 40, stepElapsed: 35, stepLength: 30, isRunning: true, now: now)
        #expect(late.step?.end == now)
    }

    @Test func aPausedWorkoutStandsStill() {
        let state = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "30 sec",
                                  elapsed: 61.8, stepElapsed: 18, stepLength: 30, isRunning: false, now: now)
        #expect(state.clock == .stopped(seconds: 61))
        #expect(state.step == nil)
        #expect(state.isPaused)
    }

    @Test func aBreathingSessionSaysWhatTheBreathIsDoing() {
        let inhale = State.breathing(subtitle: "4-4-4-4 reset", breath: .breatheIn, phaseElapsed: 1, phaseLength: 4,
                                     elapsed: 90, total: 240, isRunning: true, now: now)
        #expect(inhale.title == "Breathe in")
        #expect(inhale.breath == .breatheIn)
        // Three seconds of the in-breath to go.
        #expect(inhale.step == .init(start: now.addingTimeInterval(-1), end: now.addingTimeInterval(3)))
        // The session counts down to its end, and its bar runs start to end.
        #expect(inhale.clock == .down(to: now.addingTimeInterval(150)))
        #expect(inhale.whole == .init(start: now.addingTimeInterval(-90), end: now.addingTimeInterval(150)))

        #expect(State.breathing(subtitle: "", breath: .breatheOut, phaseElapsed: 0, phaseLength: 8,
                                elapsed: 0, total: 60, isRunning: true, now: now).title == "Breathe out")
        #expect(State.breathing(subtitle: "", breath: .holdFull, phaseElapsed: 0, phaseLength: 7,
                                elapsed: 0, total: 60, isRunning: true, now: now).title == "Hold")
    }

    @Test func everyPhaseHasItsWordSymbolAndShape() {
        typealias Breath = SessionActivityAttributes.Breath
        #expect(Breath.breatheIn.word == "In" && Breath.breatheOut.word == "Out")
        #expect(Breath.holdFull.word == "Hold" && Breath.holdEmpty.word == "Hold")
        #expect(Breath.breatheIn.symbol != Breath.breatheOut.symbol)
        // The guide is drawn full after breathing in and through the hold that follows.
        #expect(Breath.breatheIn.endsFull && Breath.holdFull.endsFull)
        #expect(!Breath.breatheOut.endsFull && !Breath.holdEmpty.endsFull)
    }

    @Test func aPausedSessionShowsNoPhase() {
        let paused = State.breathing(subtitle: "4-4-4-4 reset", breath: .breatheIn, phaseElapsed: 2, phaseLength: 4,
                                     elapsed: 90, total: 240, isRunning: false, now: now)
        #expect(paused.clock == .stopped(seconds: 150))
        #expect(paused.title == "Paused" && paused.isPaused)
        #expect(paused.breath == nil && paused.step == nil && paused.whole == nil)

        // Past the end there is nothing left, not a negative time.
        let over = State.breathing(subtitle: "", breath: .breatheOut, phaseElapsed: 9, phaseLength: 4,
                                   elapsed: 300, total: 240, isRunning: true, now: now)
        #expect(over.clock == .down(to: now))
        #expect(over.step?.end == now)
    }

    @Test func theLastMessageIsStill() {
        let done = State.finished("Session saved", seconds: 240)
        #expect(done.isFinished && done.clock == .stopped(seconds: 240) && done.title == "Session saved")
    }

    @Test func statesSurviveTheTripToTheWidget() throws {
        let states: [State] = [
            .workout(exercise: "Burpees", index: 2, count: 4, prescription: "4 × 40 sec",
                     elapsed: 300, stepElapsed: 15, stepLength: 160, isRunning: true, now: now),
            .breathing(subtitle: "Slow the breath", breath: .holdEmpty, phaseElapsed: 1, phaseLength: 4,
                       elapsed: 10, total: 360, isRunning: true, now: now),
            .finished("Workout saved", seconds: 900),
        ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            #expect(try JSONDecoder().decode(State.self, from: data) == state)
        }
    }
}
