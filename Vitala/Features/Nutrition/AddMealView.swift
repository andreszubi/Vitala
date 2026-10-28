import SwiftUI

/// Log or edit a meal. Present inside a `NavigationStack`.
struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var store = DataStore.shared

    /// If non-nil, the form is in edit mode for this meal.
    var editing: Meal? = nil
    /// Meal type to start with when logging a new meal.
    var initialType: Meal.MealType? = nil
    /// Optional default date (used when logging from a past-day Nutrition view).
    var forDate: Date? = nil

    @State private var query: String = ""
    @State private var mealType: Meal.MealType = .suggested()
    @State private var selected: [FoodItem] = []
    @State private var saving = false
    @State private var showCustomSheet = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    private var customFoods: [FoodItem] { store.customFoods }

    private var results: [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let library = FoodLibrary.common
        guard !trimmed.isEmpty else { return library }
        return (customFoods + library).filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || ($0.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var selectedCalories: Int { selected.reduce(0) { $0 + $1.calories } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.md) {
                Picker("Meal", selection: $mealType) {
                    ForEach(Meal.MealType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, VitalaSpacing.sm)

                if !selected.isEmpty {
                    SectionHeader(title: "In this meal", trailing: "\(selectedCalories) kcal")
                    ForEach(FoodGroup.grouping(selected)) { group in
                        SelectedFoodRow(group: group,
                                        onAdd: { selected.append(group.item.newInstance()) },
                                        onRemove: { removeOne(of: group) })
                    }
                }

                Button {
                    showCustomSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add custom food")
                                .font(VitalaFont.bodyMedium(15))
                            Text("Can't find it? Create your own.")
                                .font(VitalaFont.caption(12))
                                .foregroundStyle(VitalaColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(VitalaColor.muted)
                            .accessibilityHidden(true)
                    }
                    .padding(12)
                    .frame(minHeight: 44)
                    .foregroundStyle(VitalaColor.primary)
                    .background(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                        .fill(VitalaColor.primary.opacity(0.08)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle())

                if !customFoods.isEmpty && query.isEmpty {
                    SectionHeader(title: "Your foods")
                    ForEach(customFoods) { item in
                        foodButton(item, isCustom: true)
                    }
                }

                SectionHeader(title: query.isEmpty ? "Common foods" : "Results")
                if results.isEmpty {
                    EmptyStateRow(text: "No matches. Try another word or add a custom food.", icon: "magnifyingglass")
                }
                ForEach(results) { item in
                    foodButton(item, isCustom: customFoods.contains { $0.id == item.id })
                }

                if editing != nil {
                    SecondaryButton(title: "Delete this meal", icon: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .padding(.top, VitalaSpacing.sm)
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(VitalaColor.background.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: saveLabel,
                          icon: "checkmark",
                          isLoading: saving,
                          isEnabled: !selected.isEmpty) {
                Task { await save() }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, VitalaSpacing.sm)
        }
        .navigationTitle(editing == nil ? "Log a meal" : "Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showCustomSheet) {
            NavigationStack {
                CustomFoodSheet { newItem in
                    selected.append(newItem.newInstance())
                }
            }
        }
        .confirmationDialog("Delete this meal?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteMeal() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let m = editing {
                mealType = m.type
                selected = m.items
            } else if let initialType {
                mealType = initialType
            }
        }
    }

    private func foodButton(_ item: FoodItem, isCustom: Bool) -> some View {
        Button {
            selected.append(item.newInstance())
            Haptics.selection()
            AccessibilityNotification.Announcement("Added \(item.name)").post()
        } label: {
            FoodRow(item: item)
                .overlay(alignment: .topTrailing) {
                    if isCustom {
                        Text("Custom")
                            .font(VitalaFont.caption(10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(VitalaColor.primary.opacity(0.14)))
                            .foregroundStyle(VitalaColor.primary)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("\(item.name), \(item.servingSize), \(item.calories) kilocalories")
        .accessibilityHint("Adds one serving")
        .contextMenu {
            if isCustom {
                Button(role: .destructive) { deleteCustom(item) } label: {
                    Label("Delete custom food", systemImage: "trash")
                }
            }
        }
        .accessibilityActions {
            if isCustom {
                Button("Delete custom food") { deleteCustom(item) }
            }
        }
    }

    private var saveLabel: String {
        if saving { return "Saving…" }
        let base = editing == nil ? "Save meal" : "Save changes"
        return selected.isEmpty ? base : "\(base) · \(selectedCalories) kcal"
    }

    private func removeOne(of group: FoodGroup) {
        if let i = selected.lastIndex(where: { FoodGroup.key($0) == group.id }) {
            selected.remove(at: i)
        }
    }

    private func deleteCustom(_ item: FoodItem) {
        Task { try? await store.deleteCustomFood(item) }
    }

    private func save() async {
        saving = true; defer { saving = false }
        let date: Date = {
            if let m = editing { return m.date }
            guard let target = forDate, !Calendar.current.isDateInToday(target) else {
                return .now
            }
            // For backdated logs anchor to the selected day at the current time.
            let cal = Calendar.current
            let comps = cal.dateComponents([.hour, .minute], from: .now)
            return cal.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: target) ?? target
        }()
        let meal = Meal(
            id: editing?.id ?? UUID().uuidString,
            date: date,
            type: mealType,
            items: selected,
            notes: editing?.notes
        )
        try? await store.logMeal(meal)
        Haptics.success()
        dismiss()
    }

    private func deleteMeal() async {
        guard let m = editing else { return }
        try? await store.deleteMeal(m)
        dismiss()
    }
}

private struct SelectedFoodRow: View {
    let group: FoodGroup
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.item.icon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.item.name).font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text("\(group.item.calories * group.count) kcal · \(Int(group.item.proteinG * Double(group.count)))g protein")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 4)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(VitalaColor.coralText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove one \(group.item.name)")
            Text("\(group.count)")
                .font(VitalaFont.bodyMedium(16))
                .monospacedDigit()
                .frame(minWidth: 20)
                .accessibilityLabel("\(group.count) servings")
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(VitalaColor.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Add one \(group.item.name)")
        }
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
            .fill(VitalaColor.primary.opacity(0.06)))
    }
}
