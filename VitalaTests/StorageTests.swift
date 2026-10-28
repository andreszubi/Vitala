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
        #expect(DataStore(files: SecureFileStore(directory: dir), defaults: defaults).recentFoods.count == DataStore.recentFoodsLimit)
    }
}
