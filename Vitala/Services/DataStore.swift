import Combine
import Foundation
import UIKit

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
    @Published private(set) var journal: [JournalEntry] = []
    @Published private(set) var customFoods: [FoodItem] = []
    /// Foods recently added from the online database, newest first, so
    /// they can be found again instantly and offline.
    @Published private(set) var recentFoods: [FoodItem] = []
    /// Foods the user starred, newest first.
    @Published private(set) var favouriteFoods: [FoodItem] = []
    /// Meals saved to log again ("My usual breakfast"), newest first.
    @Published private(set) var savedMeals: [SavedMeal] = []
    /// Workouts the user built from the exercise library.
    @Published private(set) var customWorkouts: [Workout] = []
    /// GLP-1 doses the user took.
    @Published private(set) var glp1Doses: [GLP1Dose] = []
    /// Side effects the user noted.
    @Published private(set) var sideEffects: [SideEffectEntry] = []
    /// Weights the user recorded.
    @Published private(set) var weights: [WeightEntry] = []
    /// Something went wrong reading the data file and was put right; shown
    /// to the user once.
    @Published private(set) var notice: StorageNotice?

    nonisolated static let fileName = "logs.json"
    /// The data file as it was the last time it loaded cleanly.
    nonisolated static let backupFileName = "logs.backup.json"
    /// When the backup copy was last made. Kept here rather than read from
    /// the file's timestamp, which is an API that needs a declared reason.
    nonisolated static let backupDateKey = "vitala.logsBackupDate"
    /// Where data lived before 1.0. Read once, migrated, then removed.
    nonisolated static let legacyDefaultsKey = "vitala.demo.firestore"

    private let files: SecureFileStore
    private let defaults: UserDefaults
    /// Mirrors logs into Apple Health when the user has connected it.
    private let health: HealthKitService?
    private let saver: BackgroundSaver<Snapshot>
    /// When each entry last changed and which were deleted, for iCloud sync.
    private var changes = ChangeLog()
    /// Set when the data file exists but its bytes can't be read yet (before
    /// the first unlock after a restart). Saving would overwrite it, so
    /// writes wait until it has been read.
    private var isReadOnly = false
    private var healthUpdates: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    /// Called after the user changes something, not after a merge from iCloud.
    var onLocalChange: (() -> Void)?

    init(files: SecureFileStore = SecureFileStore(),
         defaults: UserDefaults = .standard,
         health: HealthKitService? = nil) {
        self.files = files
        self.defaults = defaults
        self.health = health
        saver = BackgroundSaver { snapshot in
            try files.save(snapshot, to: DataStore.fileName)
        }
        load()
        // Re-render screens when nights or meals arrive from Apple Health,
        // and only then: today's step count changing is not this store's news.
        if let health {
            healthUpdates = health.$importedSleep.map { _ in () }
                .merge(with: health.$importedMeals.map { _ in () })
                .dropFirst(2)
                .sink { [weak self] in self?.objectWillChange.send() }
        }
        observeAppLifecycle()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: Logs plus Apple Health

    /// Logged nights plus nights recorded by other apps. A night logged in
    /// Vitala wins over a Health night it overlaps.
    var allSleep: [SleepEntry] {
        Self.merge(sleep, with: health?.importedSleep ?? [])
    }

    /// Logged meals plus food recorded by other apps.
    var allMeals: [Meal] {
        meals + (health?.importedMeals ?? [])
    }

    nonisolated static func merge(_ logged: [SleepEntry], with imported: [SleepEntry]) -> [SleepEntry] {
        logged + imported.filter { night in
            !logged.contains { $0.bedTime < night.wakeTime && night.bedTime < $0.wakeTime }
        }
    }

    // MARK: Workouts

    func logWorkout(_ session: WorkoutSession) async throws {
        upsert(session, into: &workouts, .workout)
        persist()
        if let health { Task { await health.save(workout: session) } }
    }

    func deleteWorkout(_ session: WorkoutSession) async throws {
        remove(session.id, from: &workouts, .workout)
        persist()
        if let health { Task { await health.delete(workout: session) } }
    }

    // MARK: Meals

    func logMeal(_ meal: Meal) async throws {
        upsert(meal, into: &meals, .meal)
        persist()
    }

    func deleteMeal(_ meal: Meal) async throws {
        remove(meal.id, from: &meals, .meal)
        persist()
    }

    // MARK: Water

    func logWater(_ entry: WaterEntry) async throws {
        upsert(entry, into: &water, .water)
        persist()
        if let health { Task { await health.save(water: entry) } }
    }

    func deleteWater(_ entry: WaterEntry) async throws {
        remove(entry.id, from: &water, .water)
        persist()
        if let health { Task { await health.delete(water: entry) } }
    }

    // MARK: Sleep

    func logSleep(_ entry: SleepEntry) async throws {
        upsert(entry, into: &sleep, .sleep)
        persist()
        if let health { Task { await health.save(sleep: entry) } }
    }

    func deleteSleep(_ entry: SleepEntry) async throws {
        remove(entry.id, from: &sleep, .sleep)
        persist()
        if let health { Task { await health.delete(sleep: entry) } }
    }

    // MARK: Mindfulness

    func logMindfulness(_ entry: LoggedMindfulness) async throws {
        upsert(entry, into: &mindfulness, .mindfulness)
        persist()
        if let health { Task { await health.save(mindfulness: entry) } }
    }

    func deleteMindfulness(_ entry: LoggedMindfulness) async throws {
        remove(entry.id, from: &mindfulness, .mindfulness)
        persist()
        if let health { Task { await health.delete(mindfulness: entry) } }
    }

    // MARK: Journal

    func saveJournal(_ entry: JournalEntry) async throws {
        upsert(entry, into: &journal, .journal)
        persist()
    }

    func deleteJournal(_ entry: JournalEntry) async throws {
        remove(entry.id, from: &journal, .journal)
        persist()
    }

    // MARK: Custom foods (user-created)

    func saveCustomFood(_ food: FoodItem) async throws {
        upsert(food, into: &customFoods, .customFood)
        persist()
    }

    func deleteCustomFood(_ food: FoodItem) async throws {
        remove(food.id, from: &customFoods, .customFood)
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
        // Recent foods stay on this device, so iCloud has nothing to hear.
        persist(notifying: false)
    }

    // MARK: Favourite foods

    /// The same food in the same amount, whichever copy of it this is.
    func isFavourite(_ food: FoodItem) -> Bool {
        let key = FoodGroup.key(food)
        return favouriteFoods.contains { FoodGroup.key($0) == key }
    }

    /// Stars a food, or removes its star. Returns whether it is now a favourite.
    @discardableResult
    func toggleFavourite(_ food: FoodItem) -> Bool {
        let key = FoodGroup.key(food)
        let starred = favouriteFoods.filter { FoodGroup.key($0) == key }
        if starred.isEmpty {
            let favourite = food.newInstance()
            favouriteFoods.insert(favourite, at: 0)
            changes.markChanged(.favouriteFood, favourite.id)
        } else {
            for favourite in starred { remove(favourite.id, from: &favouriteFoods, .favouriteFood) }
        }
        persist()
        return starred.isEmpty
    }

    // MARK: Saved meals

    func saveMeal(_ meal: SavedMeal) {
        if savedMeals.contains(where: { $0.id == meal.id }) {
            upsert(meal, into: &savedMeals, .savedMeal)
        } else {
            savedMeals.insert(meal, at: 0)
            changes.markChanged(.savedMeal, meal.id)
        }
        persist()
    }

    func deleteSavedMeal(_ meal: SavedMeal) {
        remove(meal.id, from: &savedMeals, .savedMeal)
        persist()
    }

    // MARK: Custom workouts

    func saveCustomWorkout(_ workout: Workout) {
        upsert(workout, into: &customWorkouts, .customWorkout)
        persist()
    }

    func deleteCustomWorkout(_ workout: Workout) {
        remove(workout.id, from: &customWorkouts, .customWorkout)
        persist()
    }

    // MARK: GLP-1

    func saveGLP1Dose(_ dose: GLP1Dose) {
        upsert(dose, into: &glp1Doses, .glp1Dose)
        persist()
    }

    func deleteGLP1Dose(_ dose: GLP1Dose) {
        remove(dose.id, from: &glp1Doses, .glp1Dose)
        persist()
    }

    func saveSideEffect(_ entry: SideEffectEntry) {
        upsert(entry, into: &sideEffects, .sideEffect)
        persist()
    }

    func deleteSideEffect(_ entry: SideEffectEntry) {
        remove(entry.id, from: &sideEffects, .sideEffect)
        persist()
    }

    // MARK: Weight

    func logWeight(_ entry: WeightEntry) {
        upsert(entry, into: &weights, .weight)
        persist()
    }

    func deleteWeight(_ entry: WeightEntry) {
        remove(entry.id, from: &weights, .weight)
        persist()
    }

    // MARK: Erase

    /// Permanently removes every log from this device. Copies already saved
    /// to Apple Health stay there — they belong to the user's Health record.
    ///
    /// With `everywhere`, the erase is also remembered so the next iCloud
    /// sync removes the same entries from iCloud and the user's other devices.
    func eraseAll(everywhere: Bool = false, now: Date = .now) {
        summaries = [:]
        workouts = []
        meals = []
        water = []
        sleep = []
        mindfulness = []
        journal = []
        customFoods = []
        recentFoods = []
        favouriteFoods = []
        savedMeals = []
        customWorkouts = []
        glp1Doses = []
        sideEffects = []
        weights = []
        notice = nil
        saver.cancel()
        files.delete(Self.fileName)
        files.delete(Self.backupFileName)
        files.deleteDamagedFiles()
        defaults.removeObject(forKey: Self.legacyDefaultsKey)
        defaults.removeObject(forKey: Self.backupDateKey)
        isReadOnly = false
        changes = ChangeLog()
        if everywhere {
            changes.erasedBefore = now
            persist()
            flush()
        }
    }

    // MARK: Persistence

    struct Snapshot: Codable, Equatable {
        var summaries: [String: DailySummary]
        var workouts: [WorkoutSession]
        var meals: [Meal]
        var water: [WaterEntry]
        var sleep: [SleepEntry]
        var mindfulness: [LoggedMindfulness]
        var customFoods: [FoodItem]?
        var recentFoods: [FoodItem]? = nil
        var journal: [JournalEntry]? = nil
        var favouriteFoods: [FoodItem]? = nil
        var savedMeals: [SavedMeal]? = nil
        var customWorkouts: [Workout]? = nil
        var glp1Doses: [GLP1Dose]? = nil
        var sideEffects: [SideEffectEntry]? = nil
        var weights: [WeightEntry]? = nil
        var changes: ChangeLog? = nil
        /// Entries left out because they couldn't be read. Never saved.
        var skipped = 0

        enum CodingKeys: String, CodingKey {
            case summaries, workouts, meals, water, sleep, mindfulness, customFoods, recentFoods,
                 journal, favouriteFoods, savedMeals, customWorkouts, glp1Doses, sideEffects, weights, changes
        }
    }

    var snapshot: Snapshot {
        Snapshot(summaries: summaries, workouts: workouts, meals: meals, water: water,
                 sleep: sleep, mindfulness: mindfulness, customFoods: customFoods,
                 recentFoods: recentFoods, journal: journal, favouriteFoods: favouriteFoods,
                 savedMeals: savedMeals, customWorkouts: customWorkouts,
                 glp1Doses: glp1Doses, sideEffects: sideEffects, weights: weights,
                 changes: changes.isEmpty ? nil : changes)
    }

    /// Takes in what iCloud and this device agreed on. Nothing here is sent
    /// to Apple Health: the device that logged an entry already did that.
    func adopt(_ merged: Snapshot) {
        var next = merged
        // Recent foods and daily summaries are this device's own.
        next.recentFoods = recentFoods
        next.summaries = summaries
        apply(next)
        persist(notifying: false)
    }

    /// Writes anything still waiting to be saved, and returns once it is on disk.
    func flush() {
        saver.flush()
    }

    func acknowledgeNotice() {
        notice = nil
    }

    private func upsert<T: Identifiable>(_ item: T, into array: inout [T], _ kind: ChangeLog.Kind) where T.ID == String {
        if let i = array.firstIndex(where: { $0.id == item.id }) {
            array[i] = item
        } else {
            array.append(item)
        }
        changes.markChanged(kind, item.id)
    }

    private func remove<T: Identifiable>(_ id: String, from array: inout [T], _ kind: ChangeLog.Kind) where T.ID == String {
        array.removeAll { $0.id == id }
        changes.markDeleted(kind, id)
    }

    /// Hands the current state to the background writer. The arrays are
    /// shared, not copied, so this costs the same however much is logged.
    private func persist(notifying: Bool = true) {
        if !isReadOnly { saver.save(snapshot) }
        if notifying { onLocalChange?() }
    }

    private func load() {
        switch files.load(Snapshot.self, from: Self.fileName) {
        case .loaded(let snap):
            if snap.skipped > 0 {
                // Keep the file as it was before it is rewritten without
                // the entries that couldn't be read.
                files.keepDamagedCopy(of: Self.fileName)
                apply(snap)
                notice = .skippedEntries(snap.skipped)
                persist(notifying: false)
            } else {
                apply(snap)
                // A copy to fall back on if the file is ever damaged.
                saver.afterWrites { [files, defaults] in
                    files.copy(Self.fileName, to: Self.backupFileName)
                    defaults.set(Date.now, forKey: Self.backupDateKey)
                }
            }
        case .damaged:
            recoverFromDamage()
        case .unreadable:
            isReadOnly = true
        case .missing:
            migrateFromUserDefaults()
        }
    }

    /// Moves the damaged file aside and carries on from the last good copy,
    /// or from nothing if there isn't one.
    private func recoverFromDamage() {
        guard files.setAside(Self.fileName) != nil else {
            // It couldn't be moved, so it mustn't be overwritten either.
            isReadOnly = true
            return
        }
        if case .loaded(let backup) = files.load(Snapshot.self, from: Self.backupFileName) {
            apply(backup)
            notice = .restoredBackup(savedOn: defaults.object(forKey: Self.backupDateKey) as? Date)
            persist(notifying: false)
        } else {
            notice = .startedFresh
        }
    }

    /// Reads the file again once the device has been unlocked.
    private func retryLoad() {
        guard isReadOnly else { return }
        isReadOnly = false
        load()
    }

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        // Nothing may be left waiting when the app leaves the screen: it can
        // be suspended, then ended, without another chance to save.
        for name in [UIApplication.willResignActiveNotification,
                     UIApplication.didEnterBackgroundNotification,
                     UIApplication.willTerminateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.flush() }
            })
        }
        observers.append(center.addObserver(forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.retryLoad() }
        })
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
        journal = snap.journal ?? []
        favouriteFoods = snap.favouriteFoods ?? []
        savedMeals = snap.savedMeals ?? []
        customWorkouts = snap.customWorkouts ?? []
        glp1Doses = snap.glp1Doses ?? []
        sideEffects = snap.sideEffects ?? []
        weights = snap.weights ?? []
        changes = snap.changes ?? ChangeLog()
    }
}

extension DataStore.Snapshot {
    /// Reads list by list and entry by entry, so one entry that can't be
    /// decoded costs only itself. `skipped` counts what was left out.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        var skipped = 0
        summaries = (try? values.decodeIfPresent([String: DailySummary].self, forKey: .summaries)) ?? [:]
        workouts = values.salvage(WorkoutSession.self, forKey: .workouts, skipped: &skipped)
        meals = values.salvage(Meal.self, forKey: .meals, skipped: &skipped)
        water = values.salvage(WaterEntry.self, forKey: .water, skipped: &skipped)
        sleep = values.salvage(SleepEntry.self, forKey: .sleep, skipped: &skipped)
        mindfulness = values.salvage(LoggedMindfulness.self, forKey: .mindfulness, skipped: &skipped)
        customFoods = values.salvage(FoodItem.self, forKey: .customFoods, skipped: &skipped)
        recentFoods = values.salvage(FoodItem.self, forKey: .recentFoods, skipped: &skipped)
        journal = values.salvage(JournalEntry.self, forKey: .journal, skipped: &skipped)
        favouriteFoods = values.salvage(FoodItem.self, forKey: .favouriteFoods, skipped: &skipped)
        savedMeals = values.salvage(SavedMeal.self, forKey: .savedMeals, skipped: &skipped)
        customWorkouts = values.salvage(Workout.self, forKey: .customWorkouts, skipped: &skipped)
        glp1Doses = values.salvage(GLP1Dose.self, forKey: .glp1Doses, skipped: &skipped)
        sideEffects = values.salvage(SideEffectEntry.self, forKey: .sideEffects, skipped: &skipped)
        weights = values.salvage(WeightEntry.self, forKey: .weights, skipped: &skipped)
        changes = try? values.decodeIfPresent(ChangeLog.self, forKey: .changes)
        self.skipped = skipped
    }
}

/// What the user is told after a data file had to be repaired.
enum StorageNotice: Equatable, Identifiable {
    /// The file was damaged; the last good copy took its place.
    case restoredBackup(savedOn: Date?)
    /// The file loaded, apart from this many entries.
    case skippedEntries(Int)
    /// The file was damaged and there was no copy to fall back on.
    case startedFresh
    /// The profile couldn't be read, so setup starts again.
    case profileLost
    case profileRestored

    var id: String { title + message }

    var title: String {
        switch self {
        case .restoredBackup, .profileRestored: "Restored from a saved copy"
        case .skippedEntries: "Some entries couldn't be read"
        case .startedFresh: "Your logs couldn't be read"
        case .profileLost: "Your profile couldn't be read"
        }
    }

    var message: String {
        let kept = "The damaged file was kept: you can send it to support from Settings."
        switch self {
        case .restoredBackup(let date):
            let when = date.map { " from \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
            return "Vitala's data file was damaged, so it went back to the copy it saved\(when). Anything logged after that may be missing. \(kept)"
        case .skippedEntries(let count):
            return "\(count) \(count == 1 ? "entry was" : "entries were") damaged and left out. Everything else is here. \(kept)"
        case .startedFresh:
            return "Vitala's data file was damaged and there was no saved copy to go back to, so your logs start again from here. \(kept)"
        case .profileLost:
            return "Your profile file was damaged, so Vitala needs you to set it up again. Your logs are still here. \(kept)"
        case .profileRestored:
            return "Your profile file was damaged, so Vitala went back to the copy it saved. Check that your goals are as you left them. \(kept)"
        }
    }
}
