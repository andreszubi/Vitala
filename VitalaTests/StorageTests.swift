import Foundation
import UIKit
import Testing
@testable import Vitala

@MainActor
struct StorageTests {
    private func makeSandbox() -> (SecureFileStore, UserDefaults) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaTests-\(UUID().uuidString)", isDirectory: true)
        let suite = "VitalaTests-\(UUID().uuidString)"
        return (SecureFileStore(directory: dir), UserDefaults(suiteName: suite)!)
    }

    @Test func logsSurviveRelaunch() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        try await store.logMeal(Meal(date: .now, type: .lunch, items: [FoodLibrary.common[0]]))
        store.flush()

        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.water.map(\.amountMl) == [250])
        #expect(relaunched.meals.count == 1)
    }

    @Test func journalSurvivesRelaunchAndErase() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.saveJournal(JournalEntry(date: .now, mood: .calm, text: "Felt lighter.\nSecond line",
                                                 sessionId: "s1", sessionTitle: "Box breathing"))
        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.journal.first?.mood == .calm)
        #expect(relaunched.journal.first?.preview == "Felt lighter.")
        #expect(relaunched.journal.first?.sessionTitle == "Box breathing")
        relaunched.eraseAll()
        #expect(DataStore(files: files, defaults: defaults).journal.isEmpty)
    }

    @Test func journalPreviewIsShortAndNeverEmpty() {
        #expect(JournalEntry(date: .now, mood: .okay, text: "  \n ").preview == "No notes")
        #expect(JournalEntry(date: .now, mood: .okay, text: String(repeating: "a", count: 200)).preview.count == 80)
    }

    @Test func migratesLegacyUserDefaultsBlob() throws {
        let (files, defaults) = makeSandbox()
        let legacy = DataStore.Snapshot(summaries: [:], workouts: [], meals: [],
                                        water: [WaterEntry(amountMl: 500, loggedAt: .now)],
                                        sleep: [], mindfulness: [], customFoods: nil)
        defaults.set(try JSONEncoder().encode(legacy), forKey: DataStore.legacyDefaultsKey)

        let store = DataStore(files: files, defaults: defaults)
        #expect(store.water.map(\.amountMl) == [500])
        #expect(defaults.data(forKey: DataStore.legacyDefaultsKey) == nil)
        #expect(FileManager.default.fileExists(atPath: files.url(for: DataStore.fileName).path))
    }

    @Test func aDamagedFileIsSetAsideNotOverwritten() async throws {
        let (files, defaults) = makeSandbox()
        try FileManager.default.createDirectory(at: files.directory, withIntermediateDirectories: true)
        let garbage = Data("not json".utf8)
        try garbage.write(to: files.url(for: DataStore.fileName))

        let store = DataStore(files: files, defaults: defaults)
        #expect(store.notice == .startedFresh)
        // The damaged bytes are still there, under another name…
        let kept = try #require(files.damagedFiles.first)
        #expect(try Data(contentsOf: kept) == garbage)
        // …and logging works again.
        try await store.logWater(WaterEntry(amountMl: 100, loggedAt: .now))
        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.water.map(\.amountMl) == [100])
        #expect(relaunched.notice == nil)
    }

    @Test func aDamagedFileFallsBackToTheLastGoodCopy() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        store.flush()
        // A clean launch saves a copy of the file.
        let second = DataStore(files: files, defaults: defaults)
        second.flush()
        #expect(files.exists(DataStore.backupFileName))
        // The file is cut short, as if a write had been interrupted.
        let whole = try Data(contentsOf: files.url(for: DataStore.fileName))
        try whole.prefix(whole.count / 2).write(to: files.url(for: DataStore.fileName))

        let recovered = DataStore(files: files, defaults: defaults)
        #expect(recovered.water.map(\.amountMl) == [250])
        guard case .restoredBackup = recovered.notice else {
            Issue.record("expected a restore notice, got \(String(describing: recovered.notice))")
            return
        }
        #expect(files.damagedFiles.count == 1)
        recovered.flush()
        #expect(DataStore(files: files, defaults: defaults).water.count == 1)
    }

    @Test func oneBadEntryCostsOnlyItself() throws {
        let (files, defaults) = makeSandbox()
        try FileManager.default.createDirectory(at: files.directory, withIntermediateDirectories: true)
        let json = """
        {"summaries": {}, "workouts": "oops", "meals": [],
         "water": [{"id": "a", "amountMl": 250, "loggedAt": 700000000, "icon": "drop.fill"},
                   {"id": "b", "amountMl": "lots", "loggedAt": 700000100},
                   42,
                   {"id": "c", "amountMl": 500, "loggedAt": 700000200, "icon": "drop.fill"}],
         "sleep": [], "mindfulness": [],
         "journal": [{"id": "j", "date": 700000000, "mood": "elated", "text": "?"},
                     {"id": "k", "date": 700000000, "mood": "calm", "text": "Fine"}]}
        """
        try Data(json.utf8).write(to: files.url(for: DataStore.fileName))

        let store = DataStore(files: files, defaults: defaults)
        #expect(store.water.map(\.id) == ["a", "c"])
        #expect(store.journal.map(\.id) == ["k"])
        // Two water entries, one journal entry and the workouts list.
        #expect(store.notice == .skippedEntries(4))
        // The original is kept before the file is rewritten without them.
        #expect(try Data(contentsOf: try #require(files.damagedFiles.first)) == Data(json.utf8))
        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.water.count == 2)
        #expect(relaunched.notice == nil)
    }

    @Test func quickChangesBecomeOneWriteAndFlushWaitsForIt() throws {
        let lock = NSLock()
        var written: [Int] = []
        let saver = BackgroundSaver<Int>(delay: 0.05) { value in
            lock.lock(); written.append(value); lock.unlock()
        }
        for value in 1...50 { saver.save(value) }
        saver.flush()
        lock.lock(); let afterFlush = written; lock.unlock()
        #expect(afterFlush.last == 50, "the newest value is on disk when flush returns")
        #expect(afterFlush.count <= 2, "fifty changes don't mean fifty writes")

        saver.save(51)
        saver.cancel()
        saver.flush()
        lock.lock(); let afterCancel = written; lock.unlock()
        #expect(afterCancel.last == 50, "a cancelled change is never written")
    }

    @Test func savingHappensOffTheMainThread() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        // Nothing is on disk the instant the log returns; it arrives shortly after.
        var saved = false
        for _ in 0..<100 where !saved {
            try await Task.sleep(for: .milliseconds(20))
            saved = files.exists(DataStore.fileName)
        }
        #expect(saved)
    }

    @Test func aDamagedProfileGoesBackToItsSavedCopy() async throws {
        let (files, defaults) = makeSandbox()
        let store = ProfileStore(files: files, defaults: defaults)
        store.createProfile(displayName: "Sam Rivera")
        // A clean launch saves a copy.
        #expect(ProfileStore(files: files, defaults: defaults).notice == nil)
        try Data("{".utf8).write(to: files.url(for: ProfileStore.fileName))

        let recovered = ProfileStore(files: files, defaults: defaults)
        #expect(recovered.profile?.displayName == "Sam Rivera")
        #expect(recovered.notice == .profileRestored)
        #expect(files.damagedFiles.count == 1)

        // With no copy to go back to, setup starts again and says why.
        files.delete(ProfileStore.backupFileName)
        try Data("{".utf8).write(to: files.url(for: ProfileStore.fileName))
        let lost = ProfileStore(files: files, defaults: defaults)
        #expect(lost.profile == nil)
        #expect(lost.notice == .profileLost)
    }

    @Test func eraseRemovesEverything() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        store.flush()
        store.eraseAll()
        #expect(store.water.isEmpty)
        #expect(DataStore(files: files, defaults: defaults).water.isEmpty)
        #expect(!files.exists(DataStore.fileName) && !files.exists(DataStore.backupFileName))
    }

    @Test func profileMigratesAndErases() throws {
        let (files, defaults) = makeSandbox()
        let legacy = UserProfile(id: "abc", displayName: "Sam Rivera")
        defaults.set(try JSONEncoder().encode(legacy), forKey: ProfileStore.legacyDefaultsKey)

        let store = ProfileStore(files: files, defaults: defaults)
        #expect(store.profile?.displayName == "Sam Rivera")
        #expect(ProfileStore(files: files, defaults: defaults).profile?.id == "abc")

        store.erase()
        #expect(store.profile == nil)
        #expect(ProfileStore(files: files, defaults: defaults).profile == nil)
    }
}

@MainActor
struct ExportTests {
    @Test func exportContainsEveryLogAsReadableJSON() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("VitalaExport-\(UUID().uuidString)")
        let store = DataStore(files: SecureFileStore(directory: dir),
                              defaults: UserDefaults(suiteName: "VitalaExport-\(UUID().uuidString)")!)
        try await store.logWater(WaterEntry(amountMl: 330, loggedAt: .now))
        try await store.logSleep(SleepEntry(bedTime: .now.addingTimeInterval(-28_800), wakeTime: .now, quality: .great))

        let export = DataExport(profile: UserProfile(id: "1", displayName: "Sam"), store: store)
        let json = try #require(String(data: try export.jsonData(), encoding: .utf8))
        #expect(json.contains("\"amountMl\" : 330"))
        #expect(json.contains("\"quality\" : \"great\""))
        #expect(json.contains("\"displayName\" : \"Sam\""))
    }
}

@MainActor
struct AvatarTests {
    @Test func avatarIsDownscaledPersistedAndErased() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("VitalaAvatar-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "VitalaAvatar-\(UUID().uuidString)")!
        let store = ProfileStore(files: SecureFileStore(directory: dir), defaults: defaults)
        store.createProfile(displayName: "Sam")

        let big = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1500)).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2000, height: 1500))
        }
        #expect(store.setAvatar(imageData: try #require(big.pngData())))
        let saved = try #require(store.avatar)
        #expect(max(saved.size.width, saved.size.height) <= 600)

        let relaunched = ProfileStore(files: SecureFileStore(directory: dir), defaults: defaults)
        #expect(relaunched.avatar != nil)

        relaunched.erase()
        #expect(ProfileStore(files: SecureFileStore(directory: dir), defaults: defaults).avatar == nil)
    }

    @Test func rejectsNonImageData() {
        let store = ProfileStore(files: SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaAvatar-\(UUID().uuidString)")),
                                 defaults: UserDefaults(suiteName: "VitalaAvatar-\(UUID().uuidString)")!)
        #expect(!store.setAvatar(imageData: Data("not an image".utf8)))
        #expect(store.avatar == nil)
    }
}

@MainActor
struct RecentFoodTests {
    @Test func recentFoodsDedupeCapAndPersist() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("VitalaRecent-\(UUID().uuidString)")
        let defaults = UserDefaults(suiteName: "VitalaRecent-\(UUID().uuidString)")!
        let store = DataStore(files: SecureFileStore(directory: dir), defaults: defaults)
        let banana = FoodItem(name: "Banana, raw", servingSize: "1 banana (126 g)", calories: 122,
                              proteinG: 0.9, carbsG: 28.6, fatG: 0.4)
        store.rememberRecentFood(banana)
        store.rememberRecentFood(banana.newInstance())
        #expect(store.recentFoods.count == 1, "same food and serving is kept once")

        for i in 0..<40 {
            store.rememberRecentFood(FoodItem(name: "Food \(i)", servingSize: "100 g", calories: i,
                                              proteinG: 0, carbsG: 0, fatG: 0))
        }
        #expect(store.recentFoods.count == DataStore.recentFoodsLimit)
        #expect(store.recentFoods.first?.name == "Food 39")
        store.flush()
        #expect(DataStore(files: SecureFileStore(directory: dir), defaults: defaults).recentFoods.count == DataStore.recentFoodsLimit)
    }
}
