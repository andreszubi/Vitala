import Foundation
import Testing
@testable import Vitala

struct NutritionTests {
    @Test func identicalFoodsGroupWithCounts() {
        let banana = FoodLibrary.common[1]
        let yogurt = FoodLibrary.common[0]
        let items = [banana.newInstance(), yogurt.newInstance(), banana.newInstance()]
        let groups = FoodGroup.grouping(items)
        #expect(groups.map(\.item.name) == ["Banana", "Greek yogurt"])
        #expect(groups.map(\.count) == [2, 1])
    }

    @Test func mealTypeFollowsTimeOfDay() {
        let cal = Calendar.current
        func at(_ hour: Int) -> Date { cal.date(bySettingHour: hour, minute: 0, second: 0, of: .now)! }
        #expect(Meal.MealType.suggested(at: at(8)) == .breakfast)
        #expect(Meal.MealType.suggested(at: at(13)) == .lunch)
        #expect(Meal.MealType.suggested(at: at(19)) == .dinner)
        #expect(Meal.MealType.suggested(at: at(23)) == .snack)
    }

    @Test func fullNameAddsTheBrandOnlyWhenMissing() {
        var item = FoodItem(name: "Pre-biotic fiber formula", brand: "Loam", servingSize: "1 scoop",
                            calories: 25, proteinG: 0, carbsG: 8, fatG: 0)
        #expect(item.fullName == "Loam Pre-biotic fiber formula")
        item.name = "Loam pre-biotic formula"
        #expect(item.fullName == "Loam pre-biotic formula")
        item.brand = nil
        #expect(item.fullName == "Loam pre-biotic formula")
    }

    @Test func foodsSavedBeforeDetailedNutrientsStillLoad() throws {
        let saved = #"{"id":"a","name":"Granola","servingSize":"1 cup","calories":400,"proteinG":10,"carbsG":60,"fatG":12,"fiberG":5,"icon":"barcode"}"#
        let item = try JSONDecoder().decode(FoodItem.self, from: Data(saved.utf8))
        #expect(item.sugarG == nil && item.saturatedFatG == nil && item.sodiumMg == nil)
        #expect(item.displayIcon == "basket.fill")
    }

    @Test func mealTotalsCountListedNutrientsAndFlagGaps() {
        let listed = FoodItem(name: "Oat milk", servingSize: "1 cup", calories: 120, proteinG: 2, carbsG: 16,
                              fatG: 5, fiberG: 2, sugarG: 7, saturatedFatG: 0.5, sodiumMg: 100,
                              monounsaturatedFatG: 3, polyunsaturatedFatG: 1.5)
        let unlisted = FoodItem(name: "Banana", servingSize: "1", calories: 105, proteinG: 1, carbsG: 27,
                                fatG: 0.4, fiberG: 3)
        let meal = Meal(date: .now, type: .breakfast, items: [listed, unlisted])
        #expect(meal.totalFiber == 5)
        #expect(meal.totalSugar == 7)
        #expect(meal.totalSodiumMg == 100)
        #expect(meal.totalUnsaturatedFat == 4.5)
        // Nothing listed is unknown, not zero.
        #expect(Meal(date: .now, type: .snack, items: [unlisted]).totalSugar == nil)
        #expect(meal.hasUnlistedNutrients)
        #expect(!Meal(date: .now, type: .lunch, items: [listed]).hasUnlistedNutrients)
    }

    @Test func builtInFoodsListTheDetailedNutrients() {
        for food in FoodLibrary.common {
            #expect(food.sugarG != nil && food.saturatedFatG != nil && food.sodiumMg != nil
                    && food.unsaturatedFatG != nil && food.transFatG != nil, "\(food.name)")
            // The kinds of fat can't add up to more than the total.
            let kinds = (food.saturatedFatG ?? 0) + (food.unsaturatedFatG ?? 0) + (food.transFatG ?? 0)
            #expect(kinds <= food.fatG + 0.5, "\(food.name): \(kinds) g of \(food.fatG) g fat")
        }
    }

    @Test func totalsAddUpASectionAndSplitCaloriesByMacro() {
        let yogurt = FoodLibrary.common[0], banana = FoodLibrary.common[1]
        let unlisted = FoodItem(name: "Toast", servingSize: "1 slice", calories: 80, proteinG: 3, carbsG: 15, fatG: 1)
        let totals = NutritionTotals([yogurt, banana, banana])
        #expect(totals.calories == 130 + 105 * 2)
        #expect(totals.protein == 15 + 1 * 2)
        #expect(totals.sugar == 5.4 + 14.4 * 2)
        #expect(!totals.hasGaps)
        let share = try! #require(totals.share(grams: totals.protein, kcalPerGram: 4))
        #expect(abs(share - 17 * 4 / 340.0) < 0.0001)

        let mixed = NutritionTotals([yogurt, unlisted])
        #expect(mixed.hasGaps)
        #expect(mixed.sodiumMg == 55)                      // only the food that lists it
        #expect(NutritionTotals([unlisted]).sodiumMg == nil)
        #expect(NutritionTotals([]).share(grams: 0, kcalPerGram: 4) == nil)
    }
}

