import SwiftUI

/// Choose how much of a food from the online database to add.
/// Present inside a `NavigationStack`.
struct FoodPortionSheet: View {
    let result: FoodSearchResult
    let onAdd: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var portion: FoodSearchResult.Portion
    @State private var quantity: Double = 1
    /// The result's servings, plus any USDA only lists on the food's own record.
    @State private var portions: [FoodSearchResult.Portion]
    @State private var loadingPortions = false

    init(result: FoodSearchResult, onAdd: @escaping (FoodItem) -> Void) {
        self.result = result
        self.onAdd = onAdd
        _portion = State(initialValue: result.defaultPortion)
        _portions = State(initialValue: result.portions)
    }

    private var nutrients: FoodSearchResult.Nutrients {
        result.nutrients(for: portion, quantity: quantity)
    }

    /// Restaurant and other lab-analysed foods arrive per 100 g; fetch their
    /// real servings ("1 item") and select the first.
    private func loadPortions() async {
        guard result.needsPortionLookup else { return }
        loadingPortions = true
        defer { loadingPortions = false }
        guard let found = try? await FoodDatabaseClient().portions(forFoodID: result.id),
              !found.isEmpty else { return }
        let untouched = portion == result.defaultPortion && quantity == 1
        portions = found + portions.filter { p in !found.contains { $0.label == p.label } }
        if untouched { portion = found[0] }
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
                    ForEach(portions) { p in
                        Text(p.label).tag(p)
                    }
                }
                if loadingPortions {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Looking up serving sizes…")
                            .font(VitalaFont.caption(13))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                Stepper(value: $quantity, in: 0.5...20, step: 0.5) {
                    LabeledContent("Amount", value: "\(quantity.formatted()) × \(portion.label)")
                }
                .accessibilityValue("\(quantity.formatted()) × \(portion.label)")
            }

            Section {
                LabeledContent("Energy", value: "\(Int(nutrients.kcal.rounded())) kcal")
                LabeledContent("Protein", value: grams(nutrients.protein))
                LabeledContent("Carbs", value: grams(nutrients.carbs))
                LabeledContent("Fat", value: grams(nutrients.fat))
                LabeledContent("Fiber", value: grams(nutrients.fiber))
                if let sugar = nutrients.sugar { LabeledContent("Sugar", value: grams(sugar)) }
                if let saturated = nutrients.saturatedFat { LabeledContent("Saturated fat", value: grams(saturated)) }
                if let mono = nutrients.monounsaturatedFat { LabeledContent("Monounsaturated fat", value: grams(mono)) }
                if let poly = nutrients.polyunsaturatedFat { LabeledContent("Polyunsaturated fat", value: grams(poly)) }
                if let trans = nutrients.transFat { LabeledContent("Trans fat", value: grams(trans)) }
                if let sodium = nutrients.sodiumMg { LabeledContent("Sodium", value: "\(Int(sodium.rounded())) mg") }
            } header: {
                Text("Nutrition")
            } footer: {
                Text(result.source.attribution)
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .task { await loadPortions() }
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
