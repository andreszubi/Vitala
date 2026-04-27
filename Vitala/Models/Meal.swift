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
enum FoodLibrary {
    static let common: [FoodItem] = [
        .init(name: "Greek yogurt",   brand: nil, servingSize: "150 g", calories: 130, proteinG: 15, carbsG: 9,  fatG: 4,  fiberG: 0, icon: "drop.fill"),
        .init(name: "Banana",         brand: nil, servingSize: "1 medium", calories: 105, proteinG: 1, carbsG: 27, fatG: 0.4, fiberG: 3, icon: "leaf.fill"),
        .init(name: "Avocado toast",  brand: nil, servingSize: "1 slice", calories: 220, proteinG: 6, carbsG: 18, fatG: 13, fiberG: 5, icon: "fork.knife"),
        .init(name: "Chicken salad",  brand: nil, servingSize: "1 bowl", calories: 380, proteinG: 32, carbsG: 14, fatG: 22, fiberG: 5, icon: "leaf"),
        .init(name: "Salmon fillet",  brand: nil, servingSize: "150 g", calories: 280, proteinG: 30, carbsG: 0, fatG: 18, fiberG: 0, icon: "fish.fill"),
        .init(name: "Brown rice",     brand: nil, servingSize: "1 cup", calories: 215, proteinG: 5, carbsG: 45, fatG: 1.8, fiberG: 4, icon: "circle.grid.2x2"),
        .init(name: "Almonds",        brand: nil, servingSize: "30 g (24 nuts)", calories: 170, proteinG: 6, carbsG: 6, fatG: 15, fiberG: 4, icon: "circle.fill"),
        .init(name: "Espresso",       brand: nil, servingSize: "1 shot", calories: 3, proteinG: 0.1, carbsG: 0.5, fatG: 0, fiberG: 0, icon: "cup.and.saucer.fill"),
        .init(name: "Oatmeal",        brand: nil, servingSize: "1 cup", calories: 160, proteinG: 6, carbsG: 27, fatG: 3, fiberG: 4, icon: "circle.grid.2x2"),
        .init(name: "Apple",          brand: nil, servingSize: "1 medium", calories: 95, proteinG: 0.5, carbsG: 25, fatG: 0.3, fiberG: 4, icon: "leaf.fill"),
        .init(name: "Quinoa bowl",    brand: nil, servingSize: "1 bowl", calories: 420, proteinG: 14, carbsG: 60, fatG: 12, fiberG: 8, icon: "circle.grid.2x2"),
        .init(name: "Smoothie",       brand: "Berry blend", servingSize: "16 oz", calories: 250, proteinG: 8, carbsG: 45, fatG: 4, fiberG: 6, icon: "drop.fill")
    ]
}
