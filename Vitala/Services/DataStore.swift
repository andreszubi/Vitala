import Foundation

/// On-device store for everything the user logs. Data lives in a protected
/// JSON file (see `SecureFileStore`) and is published so screens update as
/// soon as something is logged elsewhere in the app.
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore(health: .shared)

    @Published private(set) var summaries: [String: DailySummary] = [:]
    @Published private(set) var workouts: [WorkoutSession] = []
    @Published private(set) var meals: [Meal] = []
    @Published private(set) var water: [WaterEntry] = []
    @Published private(set) var sleep: [SleepEntry] = []
    @Published private(set) var mindfulness: [LoggedMindfulness] = []
    @Published private(set) var customFoods: [FoodItem] = []
    /// Foods recently added from the online database, newest first, so
    /// they can be found again instantly and offline.
    @Published private(set) var recentFoods: [FoodItem] = []

    nonisolated static let fileName = "logs.json"
    /// Where data lived before 1.0. Read once, migrated, then removed.
    nonisolated static let legacyDefaultsKey = "vitala.demo.firestore"

    private let files: SecureFileStore
    private let defaults: UserDefaults
    /// Mirrors logs into Apple Health when the user has connected it.
    private let health: HealthKitService?
    /// Set when the data file exists but can't be read; persisting would
    /// overwrite it, so writes are skipped until the next launch.
    private var isReadOnly = false

    init(files: SecureFileStore = SecureFileStore(),
         defaults: UserDefaults = .standard,
         health: HealthKitService? = nil) {
        self.files = files
        self.defaults = defaults
        self.health = health
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
        upsert(session, into: &workouts)
        persist()
        if let health { Task { await health.save(workout: session) } }
    }

    func recentWorkouts(limit: Int = 20) async throws -> [WorkoutSession] {
        Array(workouts.sorted { $0.startedAt > $1.startedAt }.prefix(limit))
    }

    func deleteWorkout(_ session: WorkoutSession) async throws {
        workouts.removeAll { $0.id == session.id }
        persist()
        if let health { Task { await health.delete(workout: session) } }
    }

    // MARK: Meals

    func logMeal(_ meal: Meal) async throws {
        upsert(meal, into: &meals)
        persist()
    }

    func meals(on date: Date) async throws -> [Meal] {
        meals.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func deleteMeal(_ meal: Meal) async throws {
        meals.removeAll { $0.id == meal.id }
        persist()
    }

    // MARK: Water

    func logWater(_ entry: WaterEntry) async throws {
        upsert(entry, into: &water)
        persist()
        if let health { Task { await health.save(water: entry) } }
    }

    func water(on date: Date) async throws -> [WaterEntry] {
        water.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
    }

    func deleteWater(_ entry: WaterEntry) async throws {
        water.removeAll { $0.id == entry.id }
        persist()
        if let health { Task { await health.delete(water: entry) } }
    }

    // MARK: Sleep

    func logSleep(_ entry: SleepEntry) async throws {
        upsert(entry, into: &sleep)
        persist()
        if let health { Task { await health.save(sleep: entry) } }
    }

    func recentSleep(limit: Int = 14) async throws -> [SleepEntry] {
        Array(sleep.sorted { $0.wakeTime > $1.wakeTime }.prefix(limit))
    }

    func deleteSleep(_ entry: SleepEntry) async throws {
        sleep.removeAll { $0.id == entry.id }
        persist()
        if let health { Task { await health.delete(sleep: entry) } }
    }

    // MARK: Mindfulness

    func logMindfulness(_ entry: LoggedMindfulness) async throws {
        upsert(entry, into: &mindfulness)
        persist()
        if let health { Task { await health.save(mindfulness: entry) } }
    }

    func deleteMindfulness(_ entry: LoggedMindfulness) async throws {
        mindfulness.removeAll { $0.id == entry.id }
        persist()
        if let health { Task { await health.delete(mindfulness: entry) } }
    }

    // MARK: Custom foods (user-created)

    func saveCustomFood(_ food: FoodItem) async throws {
        upsert(food, into: &customFoods)
        persist()
    }

    func deleteCustomFood(_ food: FoodItem) async throws {
        customFoods.removeAll { $0.id == food.id }
        persist()
    }

    // MARK: Recent foods

    static let recentFoodsLimit = 25

    func rememberRecentFood(_ food: FoodItem) {
        recentFoods.removeAll { $0.name == food.name && $0.servingSize == food.servingSize }
        recentFoods.insert(food, at: 0)
        if recentFoods.count > Self.recentFoodsLimit {
            recentFoods.removeLast(recentFoods.count - Self.recentFoodsLimit)
        }
        persist()
    }

    // MARK: Erase

    /// Permanently removes every log from this device. Copies already saved
    /// to Apple Health stay there — they belong to the user's Health record.
    func eraseAll() {
        summaries = [:]
        workouts = []
        meals = []
        water = []
        sleep = []
        mindfulness = []
        customFoods = []
        recentFoods = []
        files.delete(Self.fileName)
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        isReadOnly = false
    }

    // MARK: Persistence

    struct Snapshot: Codable {
        var summaries: [String: DailySummary]
        var workouts: [WorkoutSession]
        var meals: [Meal]
        var water: [WaterEntry]
        var sleep: [SleepEntry]
        var mindfulness: [LoggedMindfulness]
        var customFoods: [FoodItem]?
        var recentFoods: [FoodItem]? = nil
    }

    var snapshot: Snapshot {
        Snapshot(summaries: summaries, workouts: workouts, meals: meals, water: water,
                 sleep: sleep, mindfulness: mindfulness, customFoods: customFoods,
                 recentFoods: recentFoods)
    }

    private func upsert<T: Identifiable>(_ item: T, into array: inout [T]) {
        if let i = array.firstIndex(where: { $0.id == item.id }) {
            array[i] = item
        } else {
            array.append(item)
        }
    }

    private func persist() {
        guard !isReadOnly else { return }
        try? files.save(snapshot, to: Self.fileName)
    }

    private func load() {
        switch files.load(Snapshot.self, from: Self.fileName) {
        case .loaded(let snap):
            apply(snap)
        case .unreadable:
            isReadOnly = true
        case .missing:
            migrateFromUserDefaults()
        }
    }

    private func migrateFromUserDefaults() {
        guard let data = defaults.data(forKey: Self.legacyDefaultsKey),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return
        }
        apply(snap)
        do {
            try files.save(snapshot, to: Self.fileName)
            defaults.removeObject(forKey: Self.legacyDefaultsKey)
        } catch {
            // Keep the legacy copy; we'll try again next launch.
        }
    }

    private func apply(_ snap: Snapshot) {
        summaries = snap.summaries
        workouts = snap.workouts
        meals = snap.meals
        water = snap.water
        sleep = snap.sleep
        mindfulness = snap.mindfulness
        customFoods = snap.customFoods ?? []
        recentFoods = snap.recentFoods ?? []
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
