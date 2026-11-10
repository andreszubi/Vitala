import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Everything Vitala stores about the user, as one JSON document they can
/// keep or move elsewhere.
struct DataExport: Codable {
    var exportedAt: Date
    var appVersion: String
    var profile: UserProfile?
    var workouts: [WorkoutSession]
    var meals: [Meal]
    var water: [WaterEntry]
    var sleep: [SleepEntry]
    var mindfulness: [LoggedMindfulness]
    var journal: [JournalEntry]
    var customFoods: [FoodItem]
    var favouriteFoods: [FoodItem]
    var savedMeals: [SavedMeal]
    var customWorkouts: [Workout]

    @MainActor
    init(profile: UserProfile?, store: DataStore, now: Date = .now) {
        exportedAt = now
        appVersion = AppInfo.versionString
        self.profile = profile
        workouts = store.workouts.sorted { $0.startedAt < $1.startedAt }
        meals = store.meals.sorted { $0.date < $1.date }
        water = store.water.sorted { $0.loggedAt < $1.loggedAt }
        sleep = store.sleep.sorted { $0.bedTime < $1.bedTime }
        mindfulness = store.mindfulness.sorted { $0.completedAt < $1.completedAt }
        journal = store.journal.sorted { $0.date < $1.date }
        customFoods = store.customFoods
        favouriteFoods = store.favouriteFoods
        savedMeals = store.savedMeals
        customWorkouts = store.customWorkouts
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// Share-sheet payload for the export.
/// Built when the share sheet asks for it, not while Settings is drawn:
/// encoding everything the user has logged is too much work to repeat on
/// every redraw.
struct ExportFile: Transferable {
    let profile: UserProfile?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { file in
            try await MainActor.run { try DataExport(profile: file.profile, store: .shared).jsonData() }
        }
        .suggestedFileName("Vitala Export.json")
    }
}
