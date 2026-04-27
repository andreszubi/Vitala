import SwiftUI

/// Modal form for adding a user-created food item.
/// On save, the item is persisted to FirestoreService.customFoods AND
/// returned via the `onAdd` callback so the caller can add it to the
/// in-progress meal immediately.
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
    @State private var icon: String = "fork.knife"

    private let iconOptions: [String] = [
        "fork.knife", "leaf.fill", "drop.fill", "fish.fill",
        "circle.grid.2x2", "carrot.fill", "cup.and.saucer.fill",
        "birthday.cake.fill", "popcorn.fill", "takeoutbag.and.cup.and.straw.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name (e.g. Mom's chicken curry)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Serving size (e.g. 1 bowl, 200 g, 1 cup)", text: $serving)
                }

                Section("Nutrition per serving") {
                    macroField("Calories", text: $calories, suffix: "kcal", keyboard: .numberPad)
                    macroField("Protein",  text: $protein,  suffix: "g",    keyboard: .decimalPad)
                    macroField("Carbs",    text: $carbs,    suffix: "g",    keyboard: .decimalPad)
                    macroField("Fat",      text: $fat,      suffix: "g",    keyboard: .decimalPad)
                    macroField("Fiber",    text: $fiber,    suffix: "g",    keyboard: .decimalPad)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                        ForEach(iconOptions, id: \.self) { sym in
                            Button {
                                icon = sym
                            } label: {
                                Image(systemName: sym)
                                    .font(.system(size: 18))
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(icon == sym ? .white : VitalaColor.textPrimary)
                                    .background(icon == sym ? VitalaColor.primary : VitalaColor.surface)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        save()
                    } label: {
                        Text("Add to meal").bold()
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                    .foregroundStyle(canSubmit ? VitalaColor.primary : VitalaColor.muted)
                } footer: {
                    Text("Custom foods are saved to your library and will appear in search.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Custom food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func macroField(_ label: String, text: Binding<String>, suffix: String, keyboard: UIKeyboardType) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .frame(maxWidth: 90)
            Text(suffix).foregroundStyle(.secondary)
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !serving.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(calories) ?? -1) >= 0
            && Int(calories) != nil
    }

    private func save() {
        let item = FoodItem(
            id: UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand,
            servingSize: serving,
            calories: Int(calories) ?? 0,
            proteinG: Double(protein) ?? 0,
            carbsG: Double(carbs) ?? 0,
            fatG: Double(fat) ?? 0,
            fiberG: Double(fiber) ?? 0,
            icon: icon
        )
        Task {
            try? await FirestoreService.shared.saveCustomFood(item)
            onAdd(item)
            dismiss()
        }
    }
}

#Preview {
    CustomFoodSheet { _ in }
}
