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

    @Test func streaksSurviveClocksChangingAtMidnight() {
        // In Chile clocks go forward at midnight, so that day starts at 01:00.
        for zone in ["America/Santiago", "Africa/Cairo", "Asia/Beirut", "America/Havana", "Europe/Madrid"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: zone)!
            // Ten days in a row in every month of the year, so each zone's change is covered.
            for month in 1...12 {
                let end = calendar.date(from: DateComponents(year: 2026, month: month, day: 14, hour: 12))!
                let active = Set((0..<10).map {
                    calendar.startOfDay(for: calendar.date(byAdding: .day, value: -$0, to: end)!)
                })
                #expect(Insights.currentStreak(activeDays: active, today: end, calendar: calendar) == 10,
                        "\(zone), month \(month)")
                let days = Insights.lastDays(10, endingOn: end, calendar: calendar)
                #expect(Set(days) == active, "\(zone), month \(month)")
            }
        }
    }

    @Test func hoursNeverShowSixtyMinutes() {
        #expect(DashboardView.hoursText(7.996) == "8h")
        #expect(DashboardView.hoursText(7.5) == "7h 30m")
        #expect(DashboardView.hoursText(7.99) == "7h 59m")
        #expect(DashboardView.hoursText(0) == "0h")
    }

    @Test func aDayPickerOnTodayFollowsMidnight() {
        let yesterdayNoon = day(27)
        let lastToday = cal.startOfDay(for: yesterdayNoon)
        let now = day(28, hour: 7)
        // Left on "today" overnight: moves on.
        #expect(DayFollowing.selection(yesterdayNoon, lastToday: lastToday, now: now, calendar: cal) == now)
        // A day chosen on purpose stays.
        #expect(DayFollowing.selection(day(20), lastToday: lastToday, now: now, calendar: cal) == day(20))
        // Same day: nothing moves, even hours later.
        #expect(DayFollowing.selection(yesterdayNoon, lastToday: lastToday, now: day(27, hour: 23), calendar: cal) == yesterdayNoon)
    }

    @Test func calorieTargetCountsDaysWithinIt() {
        let points = [(day(20), 0.0), (day(21), 1900.0), (day(22), 2200.0), (day(23), 2600.0)]
        // A limit: days with food logged that stayed at or under it.
        #expect(DailyChartDescriptor.daysOnGoal(points, goal: 2200, isLimit: true) == 2)
        // A target to reach: days at or over it.
        #expect(DailyChartDescriptor.daysOnGoal(points, goal: 2200, isLimit: false) == 2)
        #expect(DailyChartDescriptor.daysOnGoal(points, goal: 2000, isLimit: false) == 2)
        #expect(DailyChartDescriptor.daysOnGoal(points, goal: 2000, isLimit: true) == 1)
    }
}
