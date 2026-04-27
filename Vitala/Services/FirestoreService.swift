import Foundation

/// LOCAL-ONLY data store for class demo.
/// In-memory + UserDefaults persistence so the app feels real without
/// requiring Firebase. Public interface matches the old Firestore version
/// so views need no changes.
@MainActor
final class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    // In-memory caches
    @Published private(set) var summaries: [String: DailySummary] = [:]
    @Published private(set) var workouts: [WorkoutSession] = []
    @Published private(set) var meals: [Meal] = []
    @Published private(set) var water: [WaterEntry] = []
    @Published private(set) var sleep: [SleepEntry] = []
    @Published private(set) var mindfulness: [LoggedMindfulness] = []
    @Published private(set) var customFoods: [FoodItem] = []

    private let storageKey = "vitala.demo.firestore"

    private init() {
        load()
    }

    // MARK: Daily summary

    func saveDailySummary(_ summary: DailySummary) async throws {
        let key = Self.dayKey(summary.date)
        summaries[key] = summary
        persist()
    }

    func loadDailySummary(for date: Date) async throws -> DailySummary? {
        summaries[Self.dayKey(date)]
    }

    // MARK: Workouts

    func logWorkout(_ session: WorkoutSession) async throws {
        if let i = workouts.firstIndex(where: { $0.id == session.id }) {
            workouts[i] = session
        } else {
            workouts.append(session)
        }
        persist()
    }

    func recentWorkouts(limit: Int = 20) async throws -> [WorkoutSession] {
        Array(workouts.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }

    func deleteWorkout(_ session: WorkoutSession) async throws {
        workouts.removeAll { $0.id == session.id }
        persist()
    }

    // MARK: Meals

    func logMeal(_ meal: Meal) async throws {
        if let i = meals.firstIndex(where: { $0.id == meal.id }) {
            meals[i] = meal
        } else {
            meals.append(meal)
        }
        persist()
    }

    func meals(on date: Date) async throws -> [Meal] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return meals.filter { $0.date >= start && $0.date < end }
    }

    func deleteMeal(_ meal: Meal) async throws {
        meals.removeAll { $0.id == meal.id }
        persist()
    }

    // MARK: Water

    func logWater(_ entry: WaterEntry) async throws {
        if let i = water.firstIndex(where: { $0.id == entry.id }) {
            water[i] = entry
        } else {
            water.append(entry)
        }
        persist()
    }

    func water(on date: Date) async throws -> [WaterEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return water.filter { $0.loggedAt >= start && $0.loggedAt < end }
    }

    // MARK: Sleep

    func logSleep(_ entry: SleepEntry) async throws {
        if let i = sleep.firstIndex(where: { $0.id == entry.id }) {
            sleep[i] = entry
        } else {
            sleep.append(entry)
        }
        persist()
    }

    func recentSleep(limit: Int = 14) async throws -> [SleepEntry] {
        Array(sleep.sorted { $0.wakeTime > $1.wakeTime }.prefix(limit))
    }

    func deleteSleep(_ entry: SleepEntry) async throws {
        sleep.removeAll { $0.id == entry.id }
        persist()
    }

    // MARK: Mindfulness

    func logMindfulness(_ entry: LoggedMindfulness) async throws {
        if let i = mindfulness.firstIndex(where: { $0.id == entry.id }) {
            mindfulness[i] = entry
        } else {
            mindfulness.append(entry)
        }
        persist()
    }

    func deleteMindfulness(_ entry: LoggedMindfulness) async throws {
        mindfulness.removeAll { $0.id == entry.id }
        persist()
    }

    // MARK: Custom foods (user-created)

    func saveCustomFood(_ food: FoodItem) async throws {
        if let i = customFoods.firstIndex(where: { $0.id == food.id }) {
            customFoods[i] = food
        } else {
            customFoods.append(food)
        }
        persist()
    }

    func deleteCustomFood(_ food: FoodItem) async throws {
        customFoods.removeAll { $0.id == food.id }
        persist()
    }

    // MARK: Persistence

    /// Wipes all demo data. Useful for screenshots / fresh demos.
    func resetDemoData() {
        summaries = [:]
        workouts = []
        meals = []
        water = []
        sleep = []
        mindfulness = []
        customFoods = []
        persist()
    }

    private struct Snapshot: Codable {
        var summaries: [String: DailySummary]
        var workouts: [WorkoutSession]
        var meals: [Meal]
        var water: [WaterEntry]
        var sleep: [SleepEntry]
        var mindfulness: [LoggedMindfulness]
        var customFoods: [FoodItem]?
    }

    private func persist() {
        let snap = Snapshot(
            summaries: summaries,
            workouts: workouts,
            meals: meals,
            water: water,
            sleep: sleep,
            mindfulness: mindfulness,
            customFoods: customFoods
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        summaries = snap.summaries
        workouts = snap.workouts
        meals = snap.meals
        water = snap.water
        sleep = snap.sleep
        mindfulness = snap.mindfulness
        customFoods = snap.customFoods ?? []
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
