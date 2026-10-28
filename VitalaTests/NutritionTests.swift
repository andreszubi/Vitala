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
}
