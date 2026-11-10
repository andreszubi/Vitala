import Foundation
import Testing
@testable import Vitala

@MainActor
struct FavouritesTests {
    private func makeStore() -> (DataStore, SecureFileStore, UserDefaults) {
        let files = SecureFileStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("VitalaFavourites-\(UUID().uuidString)", isDirectory: true))
        let defaults = UserDefaults(suiteName: "VitalaFavourites-\(UUID().uuidString)")!
        return (DataStore(files: files, defaults: defaults), files, defaults)
    }

    private let oats = FoodItem(name: "Oatmeal", servingSize: "1 cup", calories: 160, proteinG: 6, carbsG: 27, fatG: 3)
    private let banana = FoodItem(name: "Banana", servingSize: "1 medium", calories: 105, proteinG: 1, carbsG: 27, fatG: 0.4)

    @Test func aFoodIsStarredOnceWhicheverCopyIsTapped() {
        let (store, files, defaults) = makeStore()
        #expect(store.toggleFavourite(oats))
        // The copy in a logged meal has its own id but is the same food.
        #expect(store.isFavourite(oats.newInstance()))
        #expect(!store.isFavourite(banana))
        #expect(store.toggleFavourite(banana))
        #expect(store.favouriteFoods.map(\.name) == ["Banana", "Oatmeal"], "newest first")

        // Tapping the star on another copy removes it.
        #expect(!store.toggleFavourite(oats.newInstance()))
        #expect(store.favouriteFoods.map(\.name) == ["Banana"])

        store.flush()
        #expect(DataStore(files: files, defaults: defaults).favouriteFoods.map(\.name) == ["Banana"])
    }

    @Test func aDifferentAmountIsADifferentFavourite() {
        let (store, _, _) = makeStore()
        var large = oats
        large.servingSize = "2 cups"
        large.calories = 320
        store.toggleFavourite(oats)
        #expect(!store.isFavourite(large))
    }

    @Test func savedMealsKeepTheirFoodsAndSurviveRelaunch() {
        let (store, files, defaults) = makeStore()
        let usual = SavedMeal(name: "My usual breakfast", items: [oats, banana, banana.newInstance()])
        store.saveMeal(usual)
        store.saveMeal(SavedMeal(name: "Post-run", items: [banana]))
        #expect(store.savedMeals.map(\.name) == ["Post-run", "My usual breakfast"])
        #expect(usual.totalCalories == 370)
        #expect(usual.summary == "Oatmeal, Banana")

        // Saving again under the same id renames rather than duplicates.
        var renamed = usual
        renamed.name = "Weekday breakfast"
        store.saveMeal(renamed)
        #expect(store.savedMeals.count == 2)

        store.deleteSavedMeal(store.savedMeals[0])
        store.flush()
        let relaunched = DataStore(files: files, defaults: defaults)
        #expect(relaunched.savedMeals.map(\.name) == ["Weekday breakfast"])
        #expect(relaunched.savedMeals.first?.items.count == 3)
    }

    @Test func aLongSavedMealSummarisesItself() {
        let foods = ["Eggs", "Toast", "Avocado", "Coffee"].map {
            FoodItem(name: $0, servingSize: "1", calories: 100, proteinG: 1, carbsG: 1, fatG: 1)
        }
        #expect(SavedMeal(name: "Brunch", items: foods).summary == "Eggs, Toast and 2 more")
    }

    @Test func yesterdaysMealIsOfferedAsFreshCopies() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        func at(_ day: Int, _ hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
        }
        let meals = [
            Meal(date: at(9, 8), type: .breakfast, items: [oats]),
            Meal(date: at(9, 10), type: .breakfast, items: [banana]),
            Meal(date: at(9, 13), type: .lunch, items: [banana]),
            Meal(date: at(8, 8), type: .breakfast, items: [banana, banana]),
            Meal(date: at(10, 8), type: .breakfast, items: [banana]),
        ]
        let again = Meal.eaten(.breakfast, theDayBefore: at(10, 9), in: meals, calendar: calendar)
        #expect(again.map(\.name) == ["Oatmeal", "Banana"], "both of yesterday's breakfasts, in order")
        #expect(Set(again.map(\.id)).isDisjoint(with: [oats.id, banana.id]), "copies, so each can be removed on its own")
        #expect(Meal.eaten(.dinner, theDayBefore: at(10, 9), in: meals, calendar: calendar).isEmpty)
    }

    @Test func exportIncludesFavouritesAndSavedMeals() throws {
        let (store, _, _) = makeStore()
        store.toggleFavourite(oats)
        store.saveMeal(SavedMeal(name: "My usual breakfast", items: [oats]))
        let json = try #require(String(data: try DataExport(profile: nil, store: store).jsonData(), encoding: .utf8))
        #expect(json.contains("\"favouriteFoods\""))
        #expect(json.contains("My usual breakfast"))
    }
}
