import Foundation
import Testing
@testable import Vitala

struct LiveActivityTests {
    typealias State = SessionActivityAttributes.ContentState
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func aRunningWorkoutCountsUpFromItsStart() {
        let state = State.workout(exercise: "Push-up", index: 1, count: 4, prescription: "3 × 10 reps",
                                  elapsed: 125, stepRemaining: nil, isRunning: true, now: now)
        #expect(state.title == "Push-up")
        #expect(state.detail == "Exercise 2 of 4 · 3 × 10 reps")
        // Counting up from two minutes five seconds ago reads 2:05 now.
        #expect(state.clock == .up(from: now.addingTimeInterval(-125)))
        #expect(state.stepEndsAt == nil, "an exercise counted in reps has no countdown")
        #expect(!state.isPaused && !state.isFinished)
    }

    @Test func aTimedExerciseShowsWhenItEnds() {
        let state = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "3 × 30 sec",
                                  elapsed: 20, stepRemaining: 70, isRunning: true, now: now)
        #expect(state.stepEndsAt == now.addingTimeInterval(70))
        // An exercise already past its time ends now, never in the past.
        let late = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "30 sec",
                                 elapsed: 40, stepRemaining: -5, isRunning: true, now: now)
        #expect(late.stepEndsAt == now)
    }

    @Test func aPausedWorkoutStandsStill() {
        let state = State.workout(exercise: "Plank", index: 0, count: 3, prescription: "30 sec",
                                  elapsed: 61.8, stepRemaining: 12, isRunning: false, now: now)
        #expect(state.clock == .stopped(seconds: 61))
        #expect(state.stepEndsAt == nil)
        #expect(state.isPaused)
    }

    @Test func aBreathingSessionCountsDownToItsEnd() {
        let running = State.breathing(subtitle: "4-4-4-4 reset", elapsed: 90, total: 240, isRunning: true, now: now)
        #expect(running.clock == .down(to: now.addingTimeInterval(150)))
        #expect(running.detail == "4-4-4-4 reset")
        #expect(!running.isPaused)

        let paused = State.breathing(subtitle: "4-4-4-4 reset", elapsed: 90, total: 240, isRunning: false, now: now)
        #expect(paused.clock == .stopped(seconds: 150))
        #expect(paused.title == "Paused" && paused.isPaused)

        // Past the end there is nothing left, not a negative time.
        let over = State.breathing(subtitle: "", elapsed: 300, total: 240, isRunning: true, now: now)
        #expect(over.clock == .down(to: now))
    }

    @Test func theLastMessageIsStill() {
        let done = State.finished("Session saved", seconds: 240)
        #expect(done.isFinished && done.clock == .stopped(seconds: 240) && done.title == "Session saved")
    }

    @Test func statesSurviveTheTripToTheWidget() throws {
        let states: [State] = [
            .workout(exercise: "Burpees", index: 2, count: 4, prescription: "4 × 40 sec",
                     elapsed: 300, stepRemaining: 25, isRunning: true, now: now),
            .breathing(subtitle: "Slow the breath", elapsed: 10, total: 360, isRunning: false, now: now),
            .finished("Workout saved", seconds: 900),
        ]
        for state in states {
            let data = try JSONEncoder().encode(state)
            #expect(try JSONDecoder().decode(State.self, from: data) == state)
        }
    }
}
