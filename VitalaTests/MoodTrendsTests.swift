import Foundation
import Testing
@testable import Vitala

struct MoodTrendsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    private func at(_ day: Int, _ hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    private func entry(_ day: Int, _ hour: Int = 9, _ mood: JournalEntry.Mood) -> JournalEntry {
        JournalEntry(date: at(day, hour), mood: mood, text: "")
    }

    /// 4–10 November.
    private var week: [Date] { Insights.lastDays(7, endingOn: at(10), calendar: calendar) }

    @Test func everyMoodHasAPlaceOnTheScale() {
        for mood in JournalEntry.Mood.allCases {
            #expect((1...5).contains(mood.score))
        }
        #expect(JournalEntry.Mood.great.score > JournalEntry.Mood.okay.score)
        #expect(JournalEntry.Mood.okay.score > JournalEntry.Mood.sad.score)
    }

    @Test func aDayAveragesItsEntriesAndShowsTheLatest() {
        let entries = [entry(10, 8, .great), entry(10, 21, .tired), entry(8, 9, .calm), entry(1, 9, .sad)]
        let days = MoodTrends.days(entries, in: week, calendar: calendar)
        #expect(days.map(\.date) == [calendar.startOfDay(for: at(8)), calendar.startOfDay(for: at(10))], "oldest first; 1 Nov is outside the week")
        #expect(days[1].score == 3.5)
        #expect(days[1].latest == .tired)
        #expect(days[1].entries == 2)
        #expect(days[0].score == 4)
    }

    @Test func moodsAreCountedMostOftenFirst() {
        let entries = [entry(10, 8, .calm), entry(9, 8, .tired), entry(8, 8, .calm), entry(7, 8, .good),
                       entry(6, 8, .tired), entry(5, 8, .calm), entry(1, 8, .sad)]
        let counts = MoodTrends.counts(entries, in: week, calendar: calendar)
        #expect(counts.map(\.mood) == [.calm, .tired, .good])
        #expect(counts.map(\.count) == [3, 2, 1])
        #expect(MoodTrends.headline(counts) == "Mostly calm.")
        // A tie names both, in menu order.
        let tie = MoodTrends.counts([entry(10, 8, .tired), entry(9, 8, .good)], in: week, calendar: calendar)
        #expect(MoodTrends.headline(tie) == "Mostly good and tired.")
        #expect(MoodTrends.headline([]) == nil)
    }

    @Test func aPeriodIsComparedWithTheOneBefore() {
        // 28 Oct – 3 Nov: heavy. 4–10 Nov: light.
        let heavyThenLight = [entry(1, 8, .sad), entry(2, 8, .stressed), entry(8, 8, .good), entry(9, 8, .great)]
        #expect(MoodTrends.change(heavyThenLight, in: week, calendar: calendar) == .lighter)

        let lightThenHeavy = [entry(1, 8, .great), entry(2, 8, .good), entry(8, 8, .tired), entry(9, 8, .sad)]
        #expect(MoodTrends.change(lightThenHeavy, in: week, calendar: calendar) == .heavier)

        let same = [entry(1, 8, .good), entry(2, 8, .calm), entry(8, 8, .calm), entry(9, 8, .good)]
        #expect(MoodTrends.change(same, in: week, calendar: calendar) == .steady)
        #expect(MoodTrends.Change.lighter.sentence(days: 7) == "Lighter than the 7 days before.")
    }

    @Test func oneEntryIsNotATrend() {
        let thin = [entry(1, 8, .sad), entry(8, 8, .great), entry(9, 8, .great)]
        #expect(MoodTrends.change(thin, in: week, calendar: calendar) == nil)
        #expect(MoodTrends.change([], in: week, calendar: calendar) == nil)
        #expect(MoodTrends.average([], in: week, calendar: calendar) == nil)
        #expect(MoodTrends.days([], in: week, calendar: calendar).isEmpty)
    }

    @Test func theScaleHasAWordForEveryPoint() {
        #expect(MoodTrends.word(for: 5) == "Great")
        #expect(MoodTrends.word(for: 4) == "Good")
        #expect(MoodTrends.word(for: 3.2) == "Okay")
        #expect(MoodTrends.word(for: 2) == "Low")
        #expect(MoodTrends.word(for: 1) == "Very low")
    }
}
