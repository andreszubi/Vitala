#if DEBUG
import Foundation

/// Launch arguments for UI tests and App Store screenshots. Compiled out of
/// Release builds.
///
/// - `-resetData`: start from a clean first-launch state.
/// - `-seedSampleData`: skip onboarding and fill two weeks of realistic logs.
/// - `-greetingHour <0–23>`: greet as if it were that hour, so screenshots
///   read "Good morning" under a 9:41 status bar whenever they're taken.
enum DebugLaunchOptions {
    static var greetingHour: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-greetingHour"), i + 1 < args.count,
              let hour = Int(args[i + 1]), (0..<24).contains(hour) else { return nil }
        return hour
    }

    static func apply(arguments: [String] = ProcessInfo.processInfo.arguments) {
        if arguments.contains("-resetData") || arguments.contains("-seedSampleData") {
            reset()
        }
        if arguments.contains("-seedSampleData") {
            seed()
        }
    }

    private static func reset() {
        let files = SecureFileStore()
        files.delete(DataStore.fileName)
        files.delete(ProfileStore.fileName)
        files.delete(ProfileStore.avatarFileName)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
    }

    private static func seed() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: -dayOffset, to: today)!
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }
        // Only seed times that have already happened today.
        func past(_ date: Date) -> Bool { date <= .now }

        var profile = UserProfile(id: UUID().uuidString, displayName: "Maya Chen")
        profile.dateOfBirth = cal.date(byAdding: .year, value: -31, to: today)
        profile.gender = .female
        profile.heightCm = 168
        profile.weightKg = 62
        profile.goals.primaryFocus = .balanced
        profile.createdAt = cal.date(byAdding: .month, value: -2, to: today)!

        var workouts: [WorkoutSession] = []
        var meals: [Meal] = []
        var water: [WaterEntry] = []
        var sleep: [SleepEntry] = []
        var mindful: [LoggedMindfulness] = []
        var journal: [JournalEntry] = []
        let notes = [
            "Slept well and woke up before the alarm.\n\nTen minutes of box breathing before coffee made the morning feel unhurried. Today I want to take the stairs, drink more water, and call home this evening.",
            "Busy day, but the evening walk helped. Noticed I breathe faster when I check email.",
            "Grateful for a long call with a friend.",
            "Felt scattered this morning. A slow exhale before each meeting helped.",
        ]
        let food = FoodLibrary.common

        for d in 0..<14 {
            // Water through the day.
            for (i, hour) in [8, 10, 12, 15, 17, 19].enumerated() where (d + i) % 5 != 0 {
                let t = at(d, hour, 15)
                if past(t) { water.append(WaterEntry(amountMl: [250, 350, 500][(d + i) % 3], loggedAt: t)) }
            }
            // Meals.
            let breakfast = at(d, 8, 10), lunch = at(d, 12, 40), dinner = at(d, 19, 5)
            if past(breakfast) { meals.append(Meal(date: breakfast, type: .breakfast, items: [food[8], food[1]])) }
            if past(lunch) { meals.append(Meal(date: lunch, type: .lunch, items: [food[3], food[9]])) }
            if past(dinner) { meals.append(Meal(date: dinner, type: .dinner, items: [food[4], food[5]])) }
            // Sleep ending this morning.
            let wake = at(d, 7, [0, 15, 30, 45][d % 4])
            let bed = cal.date(byAdding: .minute, value: -[450, 480, 420, 495, 465][d % 5], to: wake)!
            if past(wake) {
                sleep.append(SleepEntry(bedTime: bed, wakeTime: wake, quality: [.good, .great, .fair, .good][d % 4]))
            }
            // Workouts four days a week.
            if d % 7 != 2 && d % 7 != 5 && d % 7 != 6 {
                let library = WorkoutLibrary.all[d % WorkoutLibrary.all.count]
                let start = at(d, 7, 45)
                if past(start.addingTimeInterval(Double(library.durationMinutes) * 60)) {
                    workouts.append(WorkoutSession(workoutId: library.id, workoutName: library.name,
                                                   startedAt: start,
                                                   endedAt: start.addingTimeInterval(Double(library.durationMinutes) * 60),
                                                   durationSeconds: library.durationMinutes * 60,
                                                   caloriesBurned: library.caloriesBurned,
                                                   category: library.category))
                }
            }
            // Mindful sessions most evenings.
            let calm = at(d, 21, 30)
            if d % 3 != 1, past(calm) {
                let session = MindfulnessLibrary.all[d % MindfulnessLibrary.all.count]
                mindful.append(LoggedMindfulness(sessionId: session.id, title: session.title,
                                                 minutes: session.minutes, completedAt: calm))
            }
            // A short journal entry most mornings.
            let morning = at(d, 7, 15)
            if d % 2 == 0, past(morning) {
                let moods: [JournalEntry.Mood] = [.good, .calm, .great, .tired]
                journal.append(JournalEntry(date: morning, mood: moods[d % moods.count],
                                            text: notes[d % notes.count]))
            }
        }

        let snapshot = DataStore.Snapshot(summaries: [:], workouts: workouts, meals: meals, water: water,
                                          sleep: sleep, mindfulness: mindful, customFoods: [],
                                          journal: journal)
        let files = SecureFileStore()
        try? files.save(snapshot, to: DataStore.fileName)
        try? files.save(profile, to: ProfileStore.fileName)
        UserDefaults.standard.set(true, forKey: "vitala.hasSeenOnboarding")
        UserDefaults.standard.set(true, forKey: "vitala.hasCompletedProfile")
        UserDefaults.standard.set(true, forKey: "vitala.healthPromptDismissed")
    }
}
#endif
