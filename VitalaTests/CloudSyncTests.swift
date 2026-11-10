import Foundation
import Testing
@testable import Vitala

// MARK: - Merge rules

struct SyncMergeTests {
    typealias Snapshot = DataStore.Snapshot
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func t(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    private func empty() -> Snapshot {
        Snapshot(summaries: [:], workouts: [], meals: [], water: [], sleep: [], mindfulness: [], customFoods: nil)
    }

    private func water(_ id: String, _ ml: Int) -> WaterEntry {
        WaterEntry(id: id, amountMl: ml, loggedAt: t0)
    }

    private func snapshot(water: [WaterEntry], changed: [String: Double] = [:], deleted: [String: Double] = [:],
                          erasedBefore: Double? = nil) -> Snapshot {
        var snap = empty()
        snap.water = water
        var log = ChangeLog()
        for (id, time) in changed { log.changed[ChangeLog.key(.water, id)] = t(time) }
        for (id, time) in deleted { log.deleted[ChangeLog.key(.water, id)] = t(time) }
        log.erasedBefore = erasedBefore.map(t)
        snap.changes = log.isEmpty ? nil : log
        return snap
    }

    @Test func entriesFromBothSidesAreKept() {
        let a = snapshot(water: [water("a", 250)], changed: ["a": 1])
        let b = snapshot(water: [water("b", 500)], changed: ["b": 2])
        let merged = SyncMerge.merge(a, b)
        #expect(merged.water.map(\.id) == ["a", "b"], "this device's first, then what arrived")
        // The same result whichever side merges.
        #expect(SyncMerge.sameContent(merged, SyncMerge.merge(b, a)))
    }

    @Test func theLaterChangeWins() {
        let older = snapshot(water: [water("a", 250)], changed: ["a": 1])
        let newer = snapshot(water: [water("a", 400)], changed: ["a": 5])
        #expect(SyncMerge.merge(older, newer).water.map(\.amountMl) == [400])
        #expect(SyncMerge.merge(newer, older).water.map(\.amountMl) == [400])
    }

    @Test func entriesFromBeforeSyncingAreSimplyCombined() {
        // Logged before change times were recorded: no times at all.
        let a = snapshot(water: [water("a", 250), water("shared", 100)])
        let b = snapshot(water: [water("b", 500), water("shared", 100)])
        let merged = SyncMerge.merge(a, b)
        #expect(Set(merged.water.map(\.id)) == ["a", "b", "shared"])
        #expect(merged.changes == nil)
    }

    @Test func aDeletionIsRememberedSoTheEntryStaysGone() {
        let deletedHere = snapshot(water: [], deleted: ["a": 5])
        let stillThere = snapshot(water: [water("a", 250)], changed: ["a": 1])
        let merged = SyncMerge.merge(deletedHere, stillThere)
        #expect(merged.water.isEmpty)
        #expect(merged.changes?.deleted[ChangeLog.key(.water, "a")] == t(5))
        #expect(SyncMerge.merge(stillThere, deletedHere).water.isEmpty)
        // Merging the result again changes nothing.
        #expect(SyncMerge.sameContent(SyncMerge.merge(merged, stillThere), merged))
        // An entry with no change time is older than any deletion.
        #expect(SyncMerge.merge(deletedHere, snapshot(water: [water("a", 250)])).water.isEmpty)
    }

    @Test func anEditAfterADeletionBringsTheEntryBack() {
        let deletedEarlier = snapshot(water: [], deleted: ["a": 2])
        let editedLater = snapshot(water: [water("a", 300)], changed: ["a": 9])
        let merged = SyncMerge.merge(deletedEarlier, editedLater)
        #expect(merged.water.map(\.amountMl) == [300])
        #expect(merged.changes?.deleted.isEmpty == true)
    }

    @Test func eraseRemovesEverythingUpToThatMoment() {
        let erased = snapshot(water: [], erasedBefore: 10)
        let other = snapshot(water: [water("old", 250), water("unstamped", 100), water("new", 500)],
                             changed: ["old": 3, "new": 12], deleted: ["gone": 4])
        let merged = SyncMerge.merge(erased, other)
        #expect(merged.water.map(\.id) == ["new"], "only what was logged after the erase")
        #expect(merged.changes?.erasedBefore == t(10))
        #expect(merged.changes?.deleted.isEmpty == true, "deletions before the erase no longer need remembering")
        #expect(SyncMerge.sameContent(merged, SyncMerge.merge(other, erased)))
    }

    @Test func recentFoodsAndSummariesStayOnTheDevice() {
        var local = snapshot(water: [water("a", 250)])
        local.recentFoods = [FoodLibrary.common[0]]
        var remote = snapshot(water: [])
        remote.recentFoods = [FoodLibrary.common[1], FoodLibrary.common[2]]
        #expect(SyncMerge.merge(local, remote).recentFoods?.count == 1)
        #expect(SyncMerge.payload(from: local).recentFoods == nil)
        #expect(SyncMerge.sameContent(local, SyncMerge.payload(from: local)))
    }

    @Test func everyKindOfEntrySyncs() {
        var remote = empty()
        let food = FoodLibrary.common[0]
        remote.workouts = [WorkoutSession(workoutId: "w", workoutName: "Run", startedAt: t0, durationSeconds: 600, caloriesBurned: 80)]
        remote.meals = [Meal(date: t0, type: .lunch, items: [food])]
        remote.sleep = [SleepEntry(bedTime: t0, wakeTime: t(28_800), quality: .good)]
        remote.mindfulness = [LoggedMindfulness(sessionId: "s", title: "Box breathing", minutes: 4, completedAt: t0)]
        remote.journal = [JournalEntry(date: t0, mood: .calm, text: "Fine")]
        remote.customFoods = [food.newInstance()]
        remote.favouriteFoods = [food.newInstance()]
        remote.savedMeals = [SavedMeal(name: "Usual", items: [food])]
        remote.customWorkouts = [Workout.custom(name: "Mine", category: .hiit, difficulty: .beginner, exercises: [], weightKg: nil)]
        let merged = SyncMerge.merge(empty(), remote)
        #expect(SyncMerge.sameContent(merged, remote))
        #expect(merged.workouts.count == 1 && merged.meals.count == 1 && merged.sleep.count == 1)
        #expect(merged.mindfulness.count == 1 && merged.journal?.count == 1 && merged.customFoods?.count == 1)
        #expect(merged.favouriteFoods?.count == 1 && merged.savedMeals?.count == 1 && merged.customWorkouts?.count == 1)
    }

    @Test func thePayloadSurvivesBeingPackedAndUnpacked() throws {
        let original = snapshot(water: [water("a", 250), water("b", 500)], changed: ["a": 1.25], deleted: ["c": 2.5],
                                erasedBefore: 0.5)
        let packed = try CloudSync.encode(original)
        let unpacked = try #require(CloudSync.decode(packed))
        #expect(SyncMerge.sameContent(original, unpacked), "change times come back exactly")
        #expect(CloudSync.decode(Data("not a payload".utf8)) == nil)
    }
}

// MARK: - Syncing devices

/// iCloud, for tests: one copy, and a count of how often it was saved.
private actor CloudServer {
    var state: CloudState?
    var revision = 0
    var saves = 0
    var availability: CloudAvailability = .available
    var failure: Error?

    func set(availability: CloudAvailability) { self.availability = availability }
    func set(failure: Error?) { self.failure = failure }
    func put(_ state: CloudState?) { self.state = state; revision += 1 }

    func read() throws -> (CloudState?, Int) {
        if let failure { throw failure }
        return (state, revision)
    }

    /// Saves only if nothing was saved since `known`.
    func write(_ new: CloudState, known: Int) throws -> Int? {
        if let failure { throw failure }
        guard known == revision else { return nil }
        state = new
        revision += 1
        saves += 1
        return revision
    }

    func remove() { state = nil; revision += 1 }
}

/// One device's connection to that iCloud.
private actor DeviceCloud: CloudStateStore {
    let server: CloudServer
    private var known = 0
    /// Runs once, between this device's fetch and its save.
    private var beforeSave: (@Sendable () async -> Void)?

    init(_ server: CloudServer) { self.server = server }

    func interrupt(_ work: @escaping @Sendable () async -> Void) { beforeSave = work }

    func availability() async -> CloudAvailability { await server.availability }

    func fetch() async throws -> CloudState? {
        let (state, revision) = try await server.read()
        known = revision
        return state
    }

    func save(_ state: CloudState) async throws -> Bool {
        if let work = beforeSave {
            beforeSave = nil
            await work()
        }
        guard let revision = try await server.write(state, known: known) else { return false }
        known = revision
        return true
    }

    func delete() async throws { await server.remove() }
}

@MainActor
struct CloudSyncTests {
    private struct Device {
        let store: DataStore
        let sync: CloudSync
        let cloud: DeviceCloud
    }

    private func device(_ server: CloudServer, on: Bool = true) -> Device {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaSync-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaSync-\(UUID().uuidString)")!
        defaults.set(on, forKey: CloudSync.enabledKey)
        let store = DataStore(files: files, defaults: defaults)
        let cloud = DeviceCloud(server)
        return Device(store: store, sync: CloudSync(store: store, cloud: cloud, defaults: defaults,
                                                    quietTime: .milliseconds(20)), cloud: cloud)
    }

    private func pause() async throws { try await Task.sleep(for: .milliseconds(15)) }

    @Test func twoDevicesEndUpWithTheSameLogs() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        try await phone.store.saveJournal(JournalEntry(date: .now, mood: .calm, text: "On the phone"))
        try await other.store.logMeal(Meal(date: .now, type: .lunch, items: [FoodLibrary.common[0]]))
        other.store.toggleFavourite(FoodLibrary.common[1])

        await phone.sync.syncNow()
        await other.sync.syncNow()
        await phone.sync.syncNow()

        for store in [phone.store, other.store] {
            #expect(store.water.map(\.amountMl) == [250])
            #expect(store.journal.map(\.text) == ["On the phone"])
            #expect(store.meals.count == 1)
            #expect(store.favouriteFoods.map(\.name) == [FoodLibrary.common[1].name])
        }
        #expect(SyncMerge.sameContent(phone.store.snapshot, other.store.snapshot))
        guard case .upToDate = phone.sync.status else {
            Issue.record("expected up to date, got \(phone.sync.status)")
            return
        }
        #expect(phone.sync.lastSynced != nil)
    }

    @Test func nothingIsUploadedWhenNothingChanged() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        await other.sync.syncNow()
        await phone.sync.syncNow()
        await other.sync.syncNow()
        #expect(await server.saves == 1, "only the device with something new saves")
    }

    @Test func aDeletionReachesTheOtherDeviceAndStaysDeleted() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        let entry = WaterEntry(amountMl: 250, loggedAt: .now)
        try await phone.store.logWater(entry)
        await phone.sync.syncNow()
        await other.sync.syncNow()
        #expect(other.store.water.count == 1)

        try await other.store.deleteWater(entry)
        await other.sync.syncNow()
        await phone.sync.syncNow()
        #expect(phone.store.water.isEmpty)
        // The phone doesn't hand it back on a later sync.
        await other.sync.syncNow()
        #expect(other.store.water.isEmpty)
    }

    @Test func theLaterEditWinsOnBothDevices() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        var entry = JournalEntry(date: .now, mood: .okay, text: "First")
        try await phone.store.saveJournal(entry)
        await phone.sync.syncNow()
        await other.sync.syncNow()

        entry.text = "Edited on the phone"
        try await phone.store.saveJournal(entry)
        try await pause()
        entry.text = "Edited later on the other device"
        entry.mood = .great
        try await other.store.saveJournal(entry)

        await phone.sync.syncNow()
        await other.sync.syncNow()
        await phone.sync.syncNow()
        #expect(phone.store.journal.map(\.text) == ["Edited later on the other device"])
        #expect(other.store.journal.first?.mood == .great)
        #expect(phone.store.journal.count == 1)
    }

    @Test func aSaveThatRacesAnotherDeviceStartsAgainAndLosesNothing() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        try await other.store.logWater(WaterEntry(amountMl: 500, loggedAt: .now))
        // The other device saves after the phone has fetched but before it saves.
        let otherSync = other.sync
        await phone.cloud.interrupt { await otherSync.syncNow() }

        await phone.sync.syncNow()
        #expect(Set(phone.store.water.map(\.amountMl)) == [250, 500])
        await other.sync.syncNow()
        #expect(Set(other.store.water.map(\.amountMl)) == [250, 500])
        #expect(await server.saves == 2)
    }

    @Test func eraseEverywhereClearsTheOtherDeviceToo() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        try await other.store.saveJournal(JournalEntry(date: .now, mood: .sad, text: "Private"))
        await phone.sync.syncNow()
        await other.sync.syncNow()
        await phone.sync.syncNow()

        try await pause()
        phone.store.eraseAll(everywhere: true)
        try await pause()
        // Logged after the erase: this is a fresh start, not more to erase.
        try await phone.store.logWater(WaterEntry(amountMl: 100, loggedAt: .now))
        await phone.sync.syncNow()
        await other.sync.syncNow()

        #expect(other.store.journal.isEmpty)
        #expect(other.store.water.map(\.amountMl) == [100])
        #expect(phone.store.water.map(\.amountMl) == [100])
    }

    @Test func erasingOnlyThisDeviceLeavesICloudAlone() async throws {
        let server = CloudServer()
        let phone = device(server), other = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        phone.store.eraseAll()
        #expect(phone.store.water.isEmpty)
        await other.sync.syncNow()
        #expect(other.store.water.map(\.amountMl) == [250])
    }

    @Test func withoutAnICloudAccountNothingLeavesTheDevice() async throws {
        let server = CloudServer()
        await server.set(availability: .noAccount)
        let phone = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        #expect(phone.sync.status == .noAccount)
        #expect(await server.saves == 0)
        #expect(phone.store.water.count == 1)
    }

    @Test func switchedOffNothingLeavesTheDevice() async throws {
        let server = CloudServer()
        let phone = device(server, on: false)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        phone.sync.syncSoon()
        try await Task.sleep(for: .milliseconds(80))
        #expect(phone.sync.status == .off)
        #expect(await server.saves == 0)
    }

    @Test func aCopyFromANewerVersionIsLeftAlone() async throws {
        let server = CloudServer()
        let future = CloudState(version: CloudSync.formatVersion + 1, payload: Data("from the future".utf8))
        await server.put(future)
        let phone = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        #expect(phone.sync.status == .needsUpdate)
        #expect(await server.state == future)
        #expect(phone.store.water.count == 1, "nothing on the device changes either")
    }

    @Test func aFailureIsReportedAndTheNextSyncRecovers() async throws {
        let server = CloudServer()
        let phone = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await server.set(failure: URLError(.notConnectedToInternet))
        await phone.sync.syncNow()
        guard case .failed = phone.sync.status else {
            Issue.record("expected a failure, got \(phone.sync.status)")
            return
        }
        #expect(phone.store.water.count == 1)

        await server.set(failure: nil)
        await phone.sync.syncNow()
        #expect(await server.saves == 1)
    }

    @Test func aChangeSyncsByItselfShortlyAfter() async throws {
        let server = CloudServer()
        let phone = device(server)
        phone.sync.start()
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        try await phone.store.logWater(WaterEntry(amountMl: 300, loggedAt: .now))
        for _ in 0..<100 {
            if await server.saves > 0 { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await server.saves == 1, "two quick logs, one upload")
        // Taking in a merge isn't a local change, so it doesn't upload again.
        let other = device(server)
        try await other.store.logWater(WaterEntry(amountMl: 500, loggedAt: .now))
        await other.sync.syncNow()
        await phone.sync.syncNow()
        try await Task.sleep(for: .milliseconds(120))
        #expect(await server.saves == 2)
        #expect(phone.store.water.count == 3)
    }

    @Test func deletingTheCloudCopyKeepsTheDeviceAndTurnsSyncOff() async throws {
        let server = CloudServer()
        let phone = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()
        #expect(await server.state != nil)

        try await phone.sync.deleteCloudCopy()
        #expect(await server.state == nil)
        #expect(!phone.sync.isOn && phone.sync.status == .off)
        #expect(phone.store.water.count == 1)
    }

    @Test func whatArrivesFromICloudIsSavedOnTheDevice() async throws {
        let server = CloudServer()
        let phone = device(server)
        try await phone.store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        await phone.sync.syncNow()

        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaSync-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaSync-\(UUID().uuidString)")!
        defaults.set(true, forKey: CloudSync.enabledKey)
        let store = DataStore(files: files, defaults: defaults)
        await CloudSync(store: store, cloud: DeviceCloud(server), defaults: defaults).syncNow()
        store.flush()
        #expect(DataStore(files: files, defaults: defaults).water.map(\.amountMl) == [250])
    }
}
