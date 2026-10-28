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
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Workouts started in the current calendar week.
    static func workoutsThisWeek(_ workouts: [WorkoutSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { week.contains($0.startedAt) }.count
    }

    /// The last `count` days, oldest first, each as a start-of-day date.
    static func lastDays(_ count: Int, endingOn end: Date = .now, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: end)
        return (0..<count).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
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
