import Foundation

/// Pure calculations behind streaks, weekly progress and the Progress screen.
/// Kept free of UI and storage so they're easy to test.
enum Insights {
    /// Start-of-day dates on which the user logged anything at all.
    static func activeDays(_ snapshot: DataStore.Snapshot, calendar: Calendar = .current) -> Set<Date> {
        var dates: [Date] = []
        dates += snapshot.workouts.map(\.startedAt)
        dates += snapshot.meals.map(\.date)
        dates += snapshot.water.map(\.loggedAt)
        dates += snapshot.sleep.map(\.wakeTime)
        dates += snapshot.mindfulness.map(\.completedAt)
        return Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// Consecutive active days ending today — or ending yesterday if nothing
    /// has been logged yet today, so a streak doesn't reset at midnight.
    static func currentStreak(activeDays: Set<Date>, today: Date = .now, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !activeDays.contains(day) {
            guard let yesterday = dayBefore(day, calendar) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let prev = dayBefore(day, calendar) else { break }
            day = prev
        }
        return streak
    }

    /// The start of the day before `day`. Where clocks change at midnight
    /// (Chile, Egypt, Lebanon, Cuba) a day can start at 01:00, so stepping
    /// back 24 hours isn't enough: it has to land on that day's own start.
    private static func dayBefore(_ day: Date, _ calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: -1, to: day).map { calendar.startOfDay(for: $0) }
    }

    /// Workouts started in the current calendar week.
    static func workoutsThisWeek(_ workouts: [WorkoutSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { week.contains($0.startedAt) }.count
    }

    /// The last `count` days, oldest first, each as a start-of-day date.
    static func lastDays(_ count: Int, endingOn end: Date = .now, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: end)
        return (0..<count).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today).map { calendar.startOfDay(for: $0) }
        }
    }

    /// Sums a value per day for items that fall on each of `days`.
    static func dailyTotals<T>(_ items: [T], days: [Date], date: (T) -> Date, value: (T) -> Double,
                               calendar: Calendar = .current) -> [Date: Double] {
        let wanted = Set(days)
        var out: [Date: Double] = [:]
        for item in items {
            let day = calendar.startOfDay(for: date(item))
            guard wanted.contains(day) else { continue }
            out[day, default: 0] += value(item)
        }
        return out
    }
}

/// How the moods chosen in the journal move over time. Pure functions, so
/// the Progress screen and its tests agree.
enum MoodTrends {
    /// One day's journal: its entries' average mood score, and the mood of
    /// the last entry written that day.
    struct Day: Equatable {
        let date: Date
        let score: Double
        let latest: JournalEntry.Mood
        let entries: Int
    }

    /// A mood and how many entries chose it.
    struct Count: Equatable, Identifiable {
        let mood: JournalEntry.Mood
        let count: Int
        var id: String { mood.rawValue }
    }

    /// How a period compares with the one before it.
    enum Change: Equatable {
        case lighter, steady, heavier

        /// "Lighter than the 7 days before."
        func sentence(days: Int) -> String {
            switch self {
            case .lighter: "Lighter than the \(days) days before."
            case .steady: "About the same as the \(days) days before."
            case .heavier: "Heavier than the \(days) days before."
            }
        }
    }

    /// The days in `days` that have at least one entry, oldest first.
    static func days(_ entries: [JournalEntry], in days: [Date], calendar: Calendar = .current) -> [Day] {
        let wanted = Set(days)
        var byDay: [Date: [JournalEntry]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if wanted.contains(day) { byDay[day, default: []].append(entry) }
        }
        return byDay.map { day, written in
            let total = written.reduce(0) { $0 + $1.mood.score }
            let latest = written.max { $0.date < $1.date }?.mood ?? .okay
            return Day(date: day, score: Double(total) / Double(written.count), latest: latest, entries: written.count)
        }
        .sorted { $0.date < $1.date }
    }

    /// How often each mood was chosen on `days`, most often first. Moods
    /// chosen equally often keep the order of the mood menu.
    static func counts(_ entries: [JournalEntry], in days: [Date], calendar: Calendar = .current) -> [Count] {
        let wanted = Set(days)
        var tally: [JournalEntry.Mood: Int] = [:]
        for entry in entries where wanted.contains(calendar.startOfDay(for: entry.date)) {
            tally[entry.mood, default: 0] += 1
        }
        let order = JournalEntry.Mood.allCases
        return tally.map { Count(mood: $0.key, count: $0.value) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : (order.firstIndex(of: $0.mood) ?? 0) < (order.firstIndex(of: $1.mood) ?? 0)
            }
    }

    /// The average mood score over every entry on `days`, or nil with none.
    static func average(_ entries: [JournalEntry], in days: [Date], calendar: Calendar = .current) -> Double? {
        let wanted = Set(days)
        let scores = entries.filter { wanted.contains(calendar.startOfDay(for: $0.date)) }.map(\.mood.score)
        return scores.isEmpty ? nil : Double(scores.reduce(0, +)) / Double(scores.count)
    }

    /// Whether this period felt lighter or heavier than the same number of
    /// days before it. Nil unless both periods have at least two entries:
    /// one entry isn't a trend.
    static func change(_ entries: [JournalEntry], in days: [Date], calendar: Calendar = .current) -> Change? {
        guard let first = days.first else { return nil }
        let before = Insights.lastDays(days.count,
                                       endingOn: calendar.date(byAdding: .day, value: -1, to: first) ?? first,
                                       calendar: calendar)
        func count(_ period: [Date]) -> Int {
            let wanted = Set(period)
            return entries.filter { wanted.contains(calendar.startOfDay(for: $0.date)) }.count
        }
        guard count(days) >= 2, count(before) >= 2,
              let now = average(entries, in: days, calendar: calendar),
              let then = average(entries, in: before, calendar: calendar) else { return nil }
        if now - then >= 0.4 { return .lighter }
        if then - now >= 0.4 { return .heavier }
        return .steady
    }

    /// "Mostly calm." or "Mostly calm and good." when two moods tie.
    static func headline(_ counts: [Count]) -> String? {
        guard let top = counts.first else { return nil }
        let tied = counts.prefix { $0.count == top.count }.prefix(2).map { $0.mood.label.lowercased() }
        return "Mostly " + tied.joined(separator: " and ") + "."
    }

    /// The word for a point on the mood scale.
    static func word(for score: Double) -> String {
        switch score {
        case 4.5...: "Great"
        case 3.5..<4.5: "Good"
        case 2.5..<3.5: "Okay"
        case 1.5..<2.5: "Low"
        default: "Very low"
        }
    }
}
