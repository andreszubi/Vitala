import Foundation
import Testing
@testable import Vitala

struct InsightsTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2 // Monday
        return c
    }
    private func day(_ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
    }

    @Test func streakCountsBackFromToday() {
        let days = Set([day(26), day(27), day(28)].map { cal.startOfDay(for: $0) })
        #expect(Insights.currentStreak(activeDays: days, today: day(28), calendar: cal) == 3)
    }

    @Test func streakSurvivesUntilTodayIsLogged() {
        let days = Set([day(26), day(27)].map { cal.startOfDay(for: $0) })
        #expect(Insights.currentStreak(activeDays: days, today: day(28), calendar: cal) == 2)
    }

    @Test func streakBreaksOnAGap() {
        let days = Set([day(24), day(27), day(28)].map { cal.startOfDay(for: $0) })
        #expect(Insights.currentStreak(activeDays: days, today: day(28), calendar: cal) == 2)
        #expect(Insights.currentStreak(activeDays: [], today: day(28), calendar: cal) == 0)
    }

    @Test func activeDaysIncludeEveryKindOfLog() {
        let snap = DataStore.Snapshot(
            summaries: [:],
            workouts: [WorkoutSession(workoutId: "w", workoutName: "Run", startedAt: day(20),
                                      durationSeconds: 600, caloriesBurned: 80)],
            meals: [Meal(date: day(21), type: .lunch, items: [])],
            water: [WaterEntry(amountMl: 250, loggedAt: day(22))],
            sleep: [SleepEntry(bedTime: day(22, hour: 23), wakeTime: day(23, hour: 7), quality: .good)],
            mindfulness: [LoggedMindfulness(sessionId: "m", title: "Breathe", minutes: 5, completedAt: day(24))],
            customFoods: nil)
        #expect(Insights.activeDays(snap, calendar: cal).count == 5)
    }

    @Test func weeklyWorkoutsOnlyCountThisWeek() {
        // Oct 28 2026 is a Wednesday; the week starts Monday Oct 26.
        let sessions = [day(25), day(26), day(28)].map {
            WorkoutSession(workoutId: "w", workoutName: "Yoga", startedAt: $0, durationSeconds: 600, caloriesBurned: 50)
        }
        #expect(Insights.workoutsThisWeek(sessions, now: day(28), calendar: cal) == 2)
    }

    @Test func dailyTotalsBucketByDay() {
        let entries = [WaterEntry(amountMl: 250, loggedAt: day(27, hour: 9)),
                       WaterEntry(amountMl: 500, loggedAt: day(27, hour: 15)),
                       WaterEntry(amountMl: 300, loggedAt: day(28))]
        let days = Insights.lastDays(2, endingOn: day(28), calendar: cal)
        let totals = Insights.dailyTotals(entries, days: days, date: \.loggedAt,
                                          value: { Double($0.amountMl) }, calendar: cal)
        #expect(totals[days[0]] == 750)
        #expect(totals[days[1]] == 300)
    }

    @Test func goalsSavedBeforeNewTargetsStillDecode() throws {
        let old = #"{"dailySteps":8000,"dailyCalories":2000,"dailyWaterMl":1500,"weeklyWorkouts":3,"sleepHours":7.5,"primaryFocus":"sleepBetter"}"#
        let goals = try JSONDecoder().decode(WellnessGoals.self, from: Data(old.utf8))
        #expect(goals.dailySteps == 8000)
        #expect(goals.primaryFocus == .sleepBetter)
        #expect(goals.dailyActiveKcal == WellnessGoals().dailyActiveKcal)
        #expect(goals.dailyExerciseMinutes == 30)
    }
}
