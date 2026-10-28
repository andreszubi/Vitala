import SwiftUI

/// Choose how much of a food from the online database to add.
/// Present inside a `NavigationStack`.
struct FoodPortionSheet: View {
    let result: FoodSearchResult
    let onAdd: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var portion: FoodSearchResult.Portion
    @State private var quantity: Double = 1

    init(result: FoodSearchResult, onAdd: @escaping (FoodItem) -> Void) {
        self.result = result
        self.onAdd = onAdd
        _portion = State(initialValue: result.defaultPortion)
    }

    private var nutrients: FoodSearchResult.Nutrients {
        result.nutrients(for: portion, quantity: quantity)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.name)
                        .font(VitalaFont.headline(18))
                        .foregroundStyle(VitalaColor.textPrimary)
                    if let brand = result.brand {
                        Text(brand)
                            .font(VitalaFont.caption())
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            Section("How much?") {
                Picker("Portion", selection: $portion) {
                    ForEach(result.portions) { p in
                        Text(p.label).tag(p)
                    }
                }
                Stepper(value: $quantity, in: 0.5...20, step: 0.5) {
                    LabeledContent("Amount", value: "\(quantity.formatted()) × \(portion.label)")
                }
            }

            Section {
                LabeledContent("Energy", value: "\(Int(nutrients.kcal.rounded())) kcal")
                LabeledContent("Protein", value: grams(nutrients.protein))
                LabeledContent("Carbs", value: grams(nutrients.carbs))
                LabeledContent("Fat", value: grams(nutrients.fat))
                LabeledContent("Fiber", value: grams(nutrients.fiber))
            } header: {
                Text("Nutrition")
            } footer: {
                Text("Nutrition data from USDA FoodData Central.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Add food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    onAdd(result.foodItem(portion: portion, quantity: quantity))
                    dismiss()
                }
            }
        }
    }

    private func grams(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) g"
    }
}
