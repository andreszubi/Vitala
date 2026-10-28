import SwiftUI

/// Form for adding a user-created food item. On save, the item is persisted
/// to `DataStore.customFoods` and returned via `onAdd` so the caller can add
/// it to the in-progress meal. Present inside a `NavigationStack`.
struct CustomFoodSheet: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (FoodItem) -> Void

    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var serving: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var fiber: String = ""
    @State private var sugar: String = ""
    @State private var saturatedFat: String = ""
    @State private var monounsaturatedFat: String = ""
    @State private var polyunsaturatedFat: String = ""
    @State private var transFat: String = ""
    @State private var sodium: String = ""
    @State private var icon: String = "fork.knife"

    private let iconOptions: [(symbol: String, label: String)] = [
        ("fork.knife", "Plate"), ("leaf.fill", "Greens"), ("drop.fill", "Drink"),
        ("fish.fill", "Fish"), ("carrot.fill", "Vegetable"), ("cup.and.saucer.fill", "Hot drink"),
        ("birthday.cake.fill", "Dessert"), ("popcorn.fill", "Snack"),
        ("takeoutbag.and.cup.and.straw.fill", "Takeout"), ("circle.grid.2x2", "Grains")
    ]

    var body: some View {
        Form {
            Section("Basics") {
                FormTextField(label: "Name", text: $name, prompt: "Chicken curry", capitalization: .words)
                FormTextField(label: "Brand", text: $brand, prompt: "Optional", capitalization: .words)
                FormTextField(label: "Serving", text: $serving, prompt: "1 bowl, 200 g")
            }

            Section {
                macroField("Calories", text: $calories, suffix: "kcal", keyboard: .numberPad)
                macroField("Protein",  text: $protein,  suffix: "g",    keyboard: .decimalPad)
                macroField("Carbs",    text: $carbs,    suffix: "g",    keyboard: .decimalPad)
                macroField("Fat",      text: $fat,      suffix: "g",    keyboard: .decimalPad)
                macroField("Fiber",    text: $fiber,    suffix: "g",    keyboard: .decimalPad)
            } header: {
                Text("Nutrition per serving")
            } footer: {
                if !macrosValid {
                    Text("Use numbers only, for example 12 or 4.5.")
                        .foregroundStyle(VitalaColor.danger)
                }
            }

            Section {
                macroField("Sugar",         text: $sugar,        suffix: "g",  keyboard: .decimalPad)
                macroField("Saturated fat", text: $saturatedFat, suffix: "g",  keyboard: .decimalPad)
                macroField("Monounsaturated fat", text: $monounsaturatedFat, suffix: "g", keyboard: .decimalPad)
                macroField("Polyunsaturated fat", text: $polyunsaturatedFat, suffix: "g", keyboard: .decimalPad)
                macroField("Trans fat",     text: $transFat,     suffix: "g",  keyboard: .decimalPad)
                macroField("Sodium",        text: $sodium,       suffix: "mg", keyboard: .numberPad)
            } header: {
                Text("More detail")
            } footer: {
                Text("Optional. Leave blank if the label doesn't say.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            Section("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 8) {
                    ForEach(iconOptions, id: \.symbol) { option in
                        Button {
                            icon = option.symbol
                        } label: {
                            Image(systemName: option.symbol)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(icon == option.symbol ? .white : VitalaColor.textPrimary)
                                .background(Circle().fill(icon == option.symbol
                                                          ? AnyShapeStyle(VitalaColor.primaryGradient)
                                                          : AnyShapeStyle(VitalaColor.background)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                        .accessibilityAddTraits(icon == option.symbol ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                EmptyView()
            } footer: {
                Text("Custom foods are saved to your library and appear in search.")
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VitalaColor.background.ignoresSafeArea())
        .keyboardDoneButton()
        .navigationTitle("Custom food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { save() }
                    .disabled(!canSubmit)
            }
        }
    }

    private func macroField(_ label: String, text: Binding<String>, suffix: String, keyboard: UIKeyboardType) -> some View {
        FormTextField(label: label, text: text, prompt: "0", unit: suffix, keyboard: keyboard)
    }

    private static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        guard let v = Double(trimmed.replacingOccurrences(of: ",", with: ".")), v >= 0 else { return nil }
        return v
    }

    /// Nil for a blank field: "not listed", rather than zero.
    private static func listed(_ text: String) -> Double? {
        text.trimmingCharacters(in: .whitespaces).isEmpty ? nil : number(text)
    }

    private var macrosValid: Bool {
        [calories, protein, carbs, fat, fiber, sugar, saturatedFat, monounsaturatedFat, polyunsaturatedFat,
         transFat, sodium].allSatisfy { Self.number($0) != nil }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !serving.trimmingCharacters(in: .whitespaces).isEmpty
            && !calories.trimmingCharacters(in: .whitespaces).isEmpty
            && macrosValid
    }

    private func save() {
        let trimmedBrand = brand.trimmingCharacters(in: .whitespaces)
        let item = FoodItem(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: trimmedBrand.isEmpty ? nil : trimmedBrand,
            servingSize: serving.trimmingCharacters(in: .whitespaces),
            calories: Int((Self.number(calories) ?? 0).rounded()),
            proteinG: Self.number(protein) ?? 0,
            carbsG: Self.number(carbs) ?? 0,
            fatG: Self.number(fat) ?? 0,
            fiberG: Self.number(fiber) ?? 0,
            icon: icon,
            sugarG: Self.listed(sugar),
            saturatedFatG: Self.listed(saturatedFat),
            sodiumMg: Self.listed(sodium),
            monounsaturatedFatG: Self.listed(monounsaturatedFat),
            polyunsaturatedFatG: Self.listed(polyunsaturatedFat),
            transFatG: Self.listed(transFat)
        )
        Task {
            try? await DataStore.shared.saveCustomFood(item)
            onAdd(item)
            Haptics.success()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack { CustomFoodSheet { _ in } }
}
