import Foundation
import Testing
@testable import Vitala

struct SessionClockTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func countsWallClockTimeNotTicks() {
        let clock = SessionClock(startingAt: start)
        // Read once after five minutes with the screen locked: still right.
        #expect(clock.elapsed(at: start.addingTimeInterval(300)) == 300)
        #expect(clock.isRunning)
    }

    @Test func pausedTimeIsNotCounted() {
        var clock = SessionClock(startingAt: start)
        clock.pause(at: start.addingTimeInterval(40))
        #expect(!clock.isRunning)
        #expect(clock.elapsed(at: start.addingTimeInterval(500)) == 40)
        clock.resume(at: start.addingTimeInterval(500))
        #expect(clock.elapsed(at: start.addingTimeInterval(520)) == 60)
        // Pausing or resuming twice changes nothing.
        clock.resume(at: start.addingTimeInterval(900))
        #expect(clock.elapsed(at: start.addingTimeInterval(520)) == 60)
    }

    @Test func timeSuspendedIsLeftOut() {
        var clock = SessionClock(startingAt: start)
        // Ticking normally: nothing is left out.
        clock.leaveOutGap(since: start.addingTimeInterval(10), until: start.addingTimeInterval(10.25))
        #expect(clock.elapsed(at: start.addingTimeInterval(10.25)) == 10.25)
        // Then nothing for two minutes: the app was suspended.
        clock.leaveOutGap(since: start.addingTimeInterval(10.25), until: start.addingTimeInterval(130.25))
        #expect(abs(clock.elapsed(at: start.addingTimeInterval(130.25)) - 10.25) < 0.001)
        #expect(clock.isRunning)
    }

    @Test func aGapWhilePausedChangesNothing() {
        var clock = SessionClock(startingAt: start)
        clock.pause(at: start.addingTimeInterval(30))
        clock.leaveOutGap(since: start.addingTimeInterval(30), until: start.addingTimeInterval(3000))
        #expect(clock.elapsed(at: start.addingTimeInterval(3000)) == 30)
    }

    @Test func aClockSetBackwardsNeverGoesNegative() {
        var clock = SessionClock(startingAt: start)
        #expect(clock.elapsed(at: start.addingTimeInterval(-60)) == 0)
        clock.pause(at: start.addingTimeInterval(-60))
        #expect(clock.elapsed(at: start) == 0)
    }
}
