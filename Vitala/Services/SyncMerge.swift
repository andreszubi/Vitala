import Foundation

/// Brings two copies of the user's data together: this device's and the
/// one in iCloud. Pure functions, so every rule is unit-tested.
///
/// The rules, entry by entry:
/// - an entry only one side has is kept;
/// - when both have it, the side that changed it later wins;
/// - a deletion wins over any change made before it, and is remembered so
///   the entry doesn't come back from the other side;
/// - "Erase all data" removes everything changed up to that moment.
///
/// Merging is the same whichever side goes first and however often it is
/// repeated, so devices that sync in any order end up with the same data.
enum SyncMerge {
    typealias Snapshot = DataStore.Snapshot

    static func merge(_ local: Snapshot, _ remote: Snapshot) -> Snapshot {
        let mine = local.changes ?? ChangeLog()
        let theirs = remote.changes ?? ChangeLog()
        let erased = [mine.erasedBefore, theirs.erasedBefore].compactMap { $0 }.max()

        // Every deletion either side knows of, at its latest time.
        var deleted = mine.deleted.merging(theirs.deleted) { max($0, $1) }
        if let erased { deleted = deleted.filter { $0.value > erased } }

        var log = ChangeLog(changed: [:], deleted: deleted, erasedBefore: erased)

        func list<T: Identifiable>(_ kind: ChangeLog.Kind, _ a: [T]?, _ b: [T]?) -> [T] where T.ID == String {
            var theirsByID: [String: T] = [:]
            for item in b ?? [] { theirsByID[item.id] = item }
            var seen = Set<String>()
            var merged: [T] = []

            func consider(_ item: T, at time: Date) {
                let key = ChangeLog.key(kind, item.id)
                if let removed = log.deleted[key] {
                    // Deleted after its last change: gone. Changed after it
                    // was deleted elsewhere: back, and the deletion forgotten.
                    if removed >= time { return }
                    log.deleted[key] = nil
                }
                if let erased, time <= erased { return }
                if time != .distantPast { log.changed[key] = time }
                merged.append(item)
            }

            // This device's entries keep their order; new ones follow.
            for item in a ?? [] where seen.insert(item.id).inserted {
                let key = ChangeLog.key(kind, item.id)
                let myTime = mine.changed[key] ?? .distantPast
                if let other = theirsByID[item.id], let theirTime = theirs.changed[key], theirTime > myTime {
                    consider(other, at: theirTime)
                } else {
                    consider(item, at: myTime)
                }
            }
            var arrivals: [(item: T, time: Date)] = []
            for item in b ?? [] where !seen.contains(item.id) {
                arrivals.append((item, theirs.changed[ChangeLog.key(kind, item.id)] ?? .distantPast))
            }
            arrivals.sort { first, second in
                first.time != second.time ? first.time < second.time : first.item.id < second.item.id
            }
            for (item, time) in arrivals where seen.insert(item.id).inserted {
                consider(item, at: time)
            }
            return merged
        }

        var merged = local
        merged.workouts = list(.workout, local.workouts, remote.workouts)
        merged.meals = list(.meal, local.meals, remote.meals)
        merged.water = list(.water, local.water, remote.water)
        merged.sleep = list(.sleep, local.sleep, remote.sleep)
        merged.mindfulness = list(.mindfulness, local.mindfulness, remote.mindfulness)
        merged.journal = list(.journal, local.journal, remote.journal)
        merged.customFoods = list(.customFood, local.customFoods, remote.customFoods)
        merged.favouriteFoods = list(.favouriteFood, local.favouriteFoods, remote.favouriteFoods)
        merged.savedMeals = list(.savedMeal, local.savedMeals, remote.savedMeals)
        merged.customWorkouts = list(.customWorkout, local.customWorkouts, remote.customWorkouts)
        merged.glp1Doses = list(.glp1Dose, local.glp1Doses, remote.glp1Doses)
        merged.sideEffects = list(.sideEffect, local.sideEffects, remote.sideEffects)
        merged.changes = log.isEmpty ? nil : log
        merged.skipped = 0
        return merged
    }

    /// Whether two copies hold the same entries and the same record of
    /// changes, whatever order the entries are in. What stays on each device
    /// (recent foods, daily summaries) isn't compared.
    static func sameContent(_ a: Snapshot, _ b: Snapshot) -> Bool {
        Content(a) == Content(b)
    }

    /// What is sent to iCloud: everything that syncs, nothing that doesn't.
    static func payload(from snapshot: Snapshot) -> Snapshot {
        var payload = snapshot
        payload.recentFoods = nil
        payload.summaries = [:]
        payload.skipped = 0
        return payload
    }

    private struct Content: Equatable {
        var workouts: [String: WorkoutSession]
        var meals: [String: Meal]
        var water: [String: WaterEntry]
        var sleep: [String: SleepEntry]
        var mindfulness: [String: LoggedMindfulness]
        var journal: [String: JournalEntry]
        var customFoods: [String: FoodItem]
        var favouriteFoods: [String: FoodItem]
        var savedMeals: [String: SavedMeal]
        var customWorkouts: [String: Workout]
        var glp1Doses: [String: GLP1Dose]
        var sideEffects: [String: SideEffectEntry]
        var changes: ChangeLog

        init(_ snapshot: Snapshot) {
            func byID<T: Identifiable>(_ items: [T]?) -> [String: T] where T.ID == String {
                var all: [String: T] = [:]
                for item in items ?? [] { all[item.id] = item }
                return all
            }
            workouts = byID(snapshot.workouts)
            meals = byID(snapshot.meals)
            water = byID(snapshot.water)
            sleep = byID(snapshot.sleep)
            mindfulness = byID(snapshot.mindfulness)
            journal = byID(snapshot.journal)
            customFoods = byID(snapshot.customFoods)
            favouriteFoods = byID(snapshot.favouriteFoods)
            savedMeals = byID(snapshot.savedMeals)
            customWorkouts = byID(snapshot.customWorkouts)
            glp1Doses = byID(snapshot.glp1Doses)
            sideEffects = byID(snapshot.sideEffects)
            changes = snapshot.changes ?? ChangeLog()
        }
    }
}
