import Foundation

struct FoodItem: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var brand: String?
    var servingSize: String      // e.g. "1 cup (240 ml)"
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var fiberG: Double = 0
    var icon: String = "fork.knife"
    /// Nil when the source didn't list it (older entries, simple foods).
    var sugarG: Double? = nil
    var saturatedFatG: Double? = nil
    var sodiumMg: Double? = nil
    var monounsaturatedFatG: Double? = nil
    var polyunsaturatedFatG: Double? = nil
    var transFatG: Double? = nil

    /// Monounsaturated plus polyunsaturated, or nil if neither is listed.
    var unsaturatedFatG: Double? {
        guard monounsaturatedFatG != nil || polyunsaturatedFatG != nil else { return nil }
        return (monounsaturatedFatG ?? 0) + (polyunsaturatedFatG ?? 0)
    }

    /// "Loam Pre-biotic fiber formula": the brand, when it isn't already
    /// part of the name.
    var fullName: String {
        guard let brand, !brand.isEmpty,
              !name.localizedCaseInsensitiveContains(brand) else { return name }
        return "\(brand) \(name)"
    }

    /// Packaged foods were saved with a barcode symbol, which says nothing
    /// about the food; show a neutral one instead.
    var displayIcon: String { icon == "barcode" ? "basket.fill" : icon }

    /// Returns a copy of this food with a fresh `id`. Use when appending the
    /// same library item to a meal more than once so each entry is uniquely
    /// identifiable in `ForEach`.
    func newInstance() -> FoodItem {
        var copy = self
        copy.id = UUID().uuidString
        return copy
    }
}

struct Meal: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var type: MealType
    var items: [FoodItem]
    var notes: String?

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs:   Double { items.reduce(0) { $0 + $1.carbsG } }
    var totalFat:     Double { items.reduce(0) { $0 + $1.fatG } }
    var totalFiber:   Double { items.reduce(0) { $0 + $1.fiberG } }
    // Nil when no food in the meal lists the nutrient.
    var totalSugar:   Double? { Self.listedTotal(items.map(\.sugarG)) }
    var totalSaturatedFat: Double? { Self.listedTotal(items.map(\.saturatedFatG)) }
    var totalSodiumMg: Double? { Self.listedTotal(items.map(\.sodiumMg)) }
    var totalUnsaturatedFat: Double? { Self.listedTotal(items.map(\.unsaturatedFatG)) }

    /// The sum of the values that are listed, or nil if none are.
    static func listedTotal(_ values: [Double?]) -> Double? {
        let listed = values.compactMap { $0 }
        return listed.isEmpty ? nil : listed.reduce(0, +)
    }
    /// Some foods in the meal don't list sugar, the fat breakdown or sodium.
    var hasUnlistedNutrients: Bool {
        items.contains {
            $0.sugarG == nil || $0.saturatedFatG == nil || $0.unsaturatedFatG == nil || $0.sodiumMg == nil
        }
    }

    /// Recorded by another app and read from Apple Health; not editable here.
    var isFromHealth: Bool { id.hasPrefix("health.") }

    enum MealType: String, Codable, CaseIterable, Identifiable {
        case breakfast, lunch, dinner, snack
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .breakfast: "sun.horizon.fill"
            case .lunch: "fork.knife"
            case .dinner: "moon.stars.fill"
            case .snack: "leaf.fill"
            }
        }
    }
}

/// Curated common foods for quick logging on the AddMeal screen.
/// A set of foods added up: one food, a meal, or a whole section of the
/// day. The optional nutrients are nil when none of the foods list them.
struct NutritionTotals {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double?
    var sodiumMg: Double?
    var saturatedFat: Double?
    var monounsaturatedFat: Double?
    var polyunsaturatedFat: Double?
    var transFat: Double?
    /// Some foods leave out at least one of the optional nutrients.
    var hasGaps: Bool

    init(_ items: [FoodItem]) {
        func total(_ value: (FoodItem) -> Double?) -> Double? { Meal.listedTotal(items.map(value)) }
        calories = items.reduce(0) { $0 + $1.calories }
        protein = items.reduce(0) { $0 + $1.proteinG }
        carbs = items.reduce(0) { $0 + $1.carbsG }
        fat = items.reduce(0) { $0 + $1.fatG }
        fiber = items.reduce(0) { $0 + $1.fiberG }
        sugar = total(\.sugarG)
        sodiumMg = total(\.sodiumMg)
        saturatedFat = total(\.saturatedFatG)
        monounsaturatedFat = total(\.monounsaturatedFatG)
        polyunsaturatedFat = total(\.polyunsaturatedFatG)
        transFat = total(\.transFatG)
        hasGaps = items.contains {
            [$0.sugarG, $0.sodiumMg, $0.saturatedFatG, $0.monounsaturatedFatG,
             $0.polyunsaturatedFatG, $0.transFatG].contains { $0 == nil }
        }
    }

    /// Share of the calories a macronutrient provides (4 kcal/g protein and
    /// carbohydrate, 9 kcal/g fat), capped at 100%.
    func share(grams: Double, kcalPerGram: Double) -> Double? {
        calories > 0 ? min(1, grams * kcalPerGram / Double(calories)) : nil
    }
}

/// Typical values per serving, from USDA FoodData Central.
enum FoodLibrary {
    static let common: [FoodItem] = [
        .init(name: "Greek yogurt",   brand: nil, servingSize: "150 g", calories: 130, proteinG: 15, carbsG: 9,  fatG: 4,  fiberG: 0, icon: "drop.fill",
              sugarG: 5.4, saturatedFatG: 2.5, sodiumMg: 55, monounsaturatedFatG: 1, polyunsaturatedFatG: 0.2, transFatG: 0),
        .init(name: "Banana",         brand: nil, servingSize: "1 medium", calories: 105, proteinG: 1, carbsG: 27, fatG: 0.4, fiberG: 3, icon: "leaf.fill",
              sugarG: 14.4, saturatedFatG: 0.1, sodiumMg: 1, monounsaturatedFatG: 0.04, polyunsaturatedFatG: 0.09, transFatG: 0),
        .init(name: "Avocado toast",  brand: nil, servingSize: "1 slice", calories: 220, proteinG: 6, carbsG: 18, fatG: 13, fiberG: 5, icon: "fork.knife",
              sugarG: 2, saturatedFatG: 2, sodiumMg: 280, monounsaturatedFatG: 8, polyunsaturatedFatG: 2, transFatG: 0),
        .init(name: "Chicken salad",  brand: nil, servingSize: "1 bowl", calories: 380, proteinG: 32, carbsG: 14, fatG: 22, fiberG: 5, icon: "leaf",
              sugarG: 6, saturatedFatG: 4, sodiumMg: 620, monounsaturatedFatG: 10, polyunsaturatedFatG: 6, transFatG: 0.1),
        .init(name: "Salmon fillet",  brand: nil, servingSize: "150 g", calories: 280, proteinG: 30, carbsG: 0, fatG: 18, fiberG: 0, icon: "fish.fill",
              sugarG: 0, saturatedFatG: 4, sodiumMg: 90, monounsaturatedFatG: 5.7, polyunsaturatedFatG: 5.8, transFatG: 0),
        .init(name: "Brown rice",     brand: nil, servingSize: "1 cup", calories: 215, proteinG: 5, carbsG: 45, fatG: 1.8, fiberG: 4, icon: "circle.grid.2x2",
              sugarG: 0.7, saturatedFatG: 0.4, sodiumMg: 10, monounsaturatedFatG: 0.6, polyunsaturatedFatG: 0.6, transFatG: 0),
        .init(name: "Almonds",        brand: nil, servingSize: "30 g (24 nuts)", calories: 170, proteinG: 6, carbsG: 6, fatG: 15, fiberG: 4, icon: "circle.fill",
              sugarG: 1.3, saturatedFatG: 1.1, sodiumMg: 0, monounsaturatedFatG: 9.5, polyunsaturatedFatG: 3.6, transFatG: 0),
        .init(name: "Espresso",       brand: nil, servingSize: "1 shot", calories: 3, proteinG: 0.1, carbsG: 0.5, fatG: 0, fiberG: 0, icon: "cup.and.saucer.fill",
              sugarG: 0, saturatedFatG: 0, sodiumMg: 4, monounsaturatedFatG: 0, polyunsaturatedFatG: 0, transFatG: 0),
        .init(name: "Oatmeal",        brand: nil, servingSize: "1 cup", calories: 160, proteinG: 6, carbsG: 27, fatG: 3, fiberG: 4, icon: "circle.grid.2x2",
              sugarG: 1, saturatedFatG: 0.6, sodiumMg: 9, monounsaturatedFatG: 1, polyunsaturatedFatG: 1.2, transFatG: 0),
        .init(name: "Apple",          brand: nil, servingSize: "1 medium", calories: 95, proteinG: 0.5, carbsG: 25, fatG: 0.3, fiberG: 4, icon: "leaf.fill",
              sugarG: 19, saturatedFatG: 0.05, sodiumMg: 2, monounsaturatedFatG: 0.01, polyunsaturatedFatG: 0.1, transFatG: 0),
        .init(name: "Quinoa bowl",    brand: nil, servingSize: "1 bowl", calories: 420, proteinG: 14, carbsG: 60, fatG: 12, fiberG: 8, icon: "circle.grid.2x2",
              sugarG: 5, saturatedFatG: 1.8, sodiumMg: 480, monounsaturatedFatG: 6, polyunsaturatedFatG: 3.5, transFatG: 0),
        .init(name: "Smoothie",       brand: "Berry blend", servingSize: "16 oz", calories: 250, proteinG: 8, carbsG: 45, fatG: 4, fiberG: 6, icon: "drop.fill",
              sugarG: 34, saturatedFatG: 1.5, sodiumMg: 120, monounsaturatedFatG: 1, polyunsaturatedFatG: 1, transFatG: 0)
    ]
}
