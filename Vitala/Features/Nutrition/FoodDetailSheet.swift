import SwiftUI

/// Nutrition for one food in a logged meal. Present inside a `NavigationStack`.
struct FoodDetailSheet: View {
    let item: FoodItem
    /// How many servings of it the meal holds.
    var count: Int = 1
    /// Nil for meals that can't be edited here, such as ones from Apple Health.
    var onEditMeal: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(VitalaFont.headline(19))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(VitalaFont.bodyMedium(15))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    Text(count > 1 ? "\(count) × \(item.servingSize)" : item.servingSize)
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            NutritionFactsSections(totals: NutritionTotals(Array(repeating: item, count: count)),
                                   gapsNote: "\"Not listed\" means the label or database didn't include it.")

            if let onEditMeal {
                Section {
                    Button {
                        onEditMeal()
                        dismiss()
                    } label: {
                        Label("Edit meal", systemImage: "pencil")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// Energy, macronutrients, more nutrients and the kinds of fat, as Form
/// sections. Shared by the food and meal-section nutrition sheets.
struct NutritionFactsSections: View {
    let totals: NutritionTotals
    /// Shown under the last section when some nutrients aren't listed.
    let gapsNote: String

    var body: some View {
        Section("Energy") {
            LabeledContent("Calories", value: "\(totals.calories) kcal")
        }

        Section {
            macroRow("Protein", grams: totals.protein, kcalPerGram: 4)
            macroRow("Carbohydrates", grams: totals.carbs, kcalPerGram: 4)
            macroRow("Fat", grams: totals.fat, kcalPerGram: 9)
        } header: {
            Text("Macronutrients")
        } footer: {
            if totals.calories > 0 {
                Text("Percentages are each nutrient's share of the calories.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }

        Section("More nutrients") {
            LabeledContent("Fiber", value: Self.amount(totals.fiber, unit: "g"))
            LabeledContent("Sugar", value: Self.listed(totals.sugar, unit: "g"))
            LabeledContent("Sodium", value: Self.listed(totals.sodiumMg, unit: "mg"))
        }

        Section {
            LabeledContent("Saturated", value: Self.listed(totals.saturatedFat, unit: "g"))
            LabeledContent("Monounsaturated", value: Self.listed(totals.monounsaturatedFat, unit: "g"))
            LabeledContent("Polyunsaturated", value: Self.listed(totals.polyunsaturatedFat, unit: "g"))
            LabeledContent("Trans", value: Self.listed(totals.transFat, unit: "g"))
        } header: {
            Text("Kinds of fat")
        } footer: {
            if totals.hasGaps {
                Text(gapsNote)
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
    }

    private func macroRow(_ label: String, grams: Double, kcalPerGram: Double) -> some View {
        let value = totals.share(grams: grams, kcalPerGram: kcalPerGram).map {
            "\(Self.amount(grams, unit: "g")) · \($0.formatted(.percent.precision(.fractionLength(0))))"
        } ?? Self.amount(grams, unit: "g")
        return LabeledContent(label, value: value)
    }

    static func amount(_ value: Double, unit: String) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...(unit == "mg" ? 0 : 1))))) \(unit)"
    }

    private static func listed(_ value: Double?, unit: String) -> String {
        value.map { amount($0, unit: unit) } ?? "Not listed"
    }
}

/// Everything eaten for one meal of the day (breakfast, lunch…), added up,
/// with the foods it came from. Present inside a `NavigationStack`.
struct MealNutritionSheet: View {
    let type: Meal.MealType
    let date: Date
    let meals: [Meal]

    @Environment(\.dismiss) private var dismiss

    private var items: [FoodItem] { meals.flatMap(\.items) }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Label(type.label, systemImage: type.icon)
                        .font(VitalaFont.headline(19))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(dayLabel) · \(items.count) \(items.count == 1 ? "food" : "foods")")
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            NutritionFactsSections(totals: NutritionTotals(items),
                                   gapsNote: "Some foods don't list every nutrient, so those totals may be low.")

            Section("Foods") {
                ForEach(FoodGroup.grouping(items)) { group in
                    NavigationLink {
                        FoodDetailSheet(item: group.item, count: group.count)
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.item.fullName)
                                    .foregroundStyle(VitalaColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(group.count > 1 ? "\(group.count) × \(group.item.servingSize)" : group.item.servingSize)
                                    .font(VitalaFont.caption(12))
                                    .foregroundStyle(VitalaColor.textSecondary)
                            }
                            Spacer(minLength: 8)
                            Text("\(group.item.calories * group.count) kcal")
                                .font(VitalaFont.caption(13))
                                .foregroundStyle(VitalaColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("\(type.label) nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FoodDetailSheet(item: FoodItem(name: "Pre-biotic fiber formula", brand: "Loam",
                                       servingSize: "1 scoop (10 g)", calories: 25, proteinG: 0,
                                       carbsG: 8, fatG: 0, fiberG: 6, icon: "basket.fill",
                                       sugarG: 0, saturatedFatG: 0, sodiumMg: 15),
                        onEditMeal: {})
    }
}
