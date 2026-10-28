import Foundation
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

        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.water.map(\.amountMl) == [250])
        #expect(relaunched.meals.count == 1)
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

    @Test func unreadableFileIsNeverOverwritten() async throws {
        let (files, defaults) = makeSandbox()
        try FileManager.default.createDirectory(at: files.directory, withIntermediateDirectories: true)
        let garbage = Data("not json".utf8)
        try garbage.write(to: files.url(for: DataStore.fileName))

        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 100, loggedAt: .now))
        #expect(try Data(contentsOf: files.url(for: DataStore.fileName)) == garbage)
    }

    @Test func eraseRemovesEverything() async throws {
        let (files, defaults) = makeSandbox()
        let store = DataStore(files: files, defaults: defaults)
        try await store.logWater(WaterEntry(amountMl: 250, loggedAt: .now))
        store.eraseAll()
        #expect(store.water.isEmpty)
        #expect(DataStore(files: files, defaults: defaults).water.isEmpty)
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
