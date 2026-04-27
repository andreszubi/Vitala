import SwiftUI

struct AddMealView: View {
    @Environment(\.dismiss) var dismiss

    /// If non-nil, the form is in edit mode for this meal.
    var editing: Meal? = nil
    /// Optional default date (used when logging from a past-day Nutrition view).
    var forDate: Date? = nil

    @State private var query: String = ""
    @State private var mealType: Meal.MealType = .lunch
    @State private var selected: [FoodItem] = []
    @State private var saving = false
    @State private var customFoods: [FoodItem] = []
    @State private var showCustomSheet = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    private var allKnownFoods: [FoodItem] {
        customFoods + FoodLibrary.common
    }

    private var results: [FoodItem] {
        if query.trimmingCharacters(in: .whitespaces).isEmpty { return allKnownFoods }
        return allKnownFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.md) {
                Text(editing == nil ? "Log a meal" : "Edit meal")
                    .font(VitalaFont.title(26))
                    .padding(.top, VitalaSpacing.md)

                Picker("", selection: $mealType) {
                    ForEach(Meal.MealType.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(VitalaColor.muted)
                    TextField("Search foods", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(14)
                .background(VitalaColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))

                Button {
                    showCustomSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add custom food")
                                .font(VitalaFont.bodyMedium(15))
                            Text("Doesn't show up in search? Create your own.")
                                .font(VitalaFont.caption(12))
                                .foregroundStyle(VitalaColor.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitalaColor.muted)
                    }
                    .padding(12)
                    .foregroundStyle(VitalaColor.primary)
                    .background(VitalaColor.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                }
                .buttonStyle(.plain)

                if !selected.isEmpty {
                    SectionHeader(title: "Selected (\(selected.count))")
                    // Enumerated id keeps SwiftUI happy even if legacy items
                    // share the same FoodItem.id.
                    ForEach(Array(selected.enumerated()), id: \.offset) { idx, item in
                        SelectedFoodRow(item: item) {
                            if selected.indices.contains(idx) {
                                selected.remove(at: idx)
                            }
                        }
                    }
                }

                if !customFoods.isEmpty && query.isEmpty {
                    SectionHeader(title: "Your foods")
                    ForEach(customFoods) { item in
                        FoodPickerRow(item: item, isCustom: true) {
                            selected.append(item.newInstance())
                        } onDelete: {
                            Task {
                                try? await FirestoreService.shared.deleteCustomFood(item)
                                await loadCustom()
                            }
                        }
                    }
                }

                SectionHeader(title: query.isEmpty ? "Common foods" : "Results")
                ForEach(results.filter { item in customFoods.first(where: { $0.id == item.id }) == nil }) { item in
                    Button {
                        selected.append(item.newInstance())
                    } label: {
                        FoodRow(item: item)
                    }
                    .buttonStyle(.plain)
                }

                if editing != nil {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete this meal").font(VitalaFont.bodyMedium(15))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VitalaColor.coral.opacity(0.12))
                        .foregroundStyle(VitalaColor.coral)
                        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, VitalaSpacing.sm)
                }

                Spacer().frame(height: 80)
            }
            .padding(.horizontal, VitalaSpacing.lg)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            PrimaryButton(title: saveLabel,
                          icon: "checkmark",
                          isLoading: saving,
                          isEnabled: !selected.isEmpty) {
                Task { await save() }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.lg)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomSheet) {
            CustomFoodSheet { newItem in
                selected.append(newItem)
                Task { await loadCustom() }
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
        .task { await loadCustom() }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let m = editing {
                mealType = m.type
                selected = m.items
            }
        }
    }

    private var saveLabel: String {
        if saving { return "Saving…" }
        return editing == nil ? "Save meal" : "Save changes"
    }

    private func loadCustom() async {
        customFoods = FirestoreService.shared.customFoods
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
            var anchor = cal.startOfDay(for: target)
            anchor = cal.date(byAdding: .hour, value: comps.hour ?? 12, to: anchor) ?? anchor
            anchor = cal.date(byAdding: .minute, value: comps.minute ?? 0, to: anchor) ?? anchor
            return min(anchor, .now)
        }()
        let meal = Meal(
            id: editing?.id ?? UUID().uuidString,
            date: date,
            type: mealType,
            items: selected,
            notes: editing?.notes
        )
        try? await FirestoreService.shared.logMeal(meal)
        dismiss()
    }

    private func deleteMeal() async {
        guard let m = editing else { return }
        try? await FirestoreService.shared.deleteMeal(m)
        dismiss()
    }
}

private struct SelectedFoodRow: View {
    let item: FoodItem
    let onRemove: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon).foregroundStyle(VitalaColor.primary).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(VitalaFont.bodyMedium(15))
                Text("\(item.calories) kcal · \(Int(item.proteinG))g P · \(Int(item.carbsG))g C · \(Int(item.fatG))g F")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(VitalaColor.coral)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(VitalaColor.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.sm))
    }
}

private struct FoodPickerRow: View {
    let item: FoodItem
    var isCustom: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(VitalaColor.sage.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: item.icon).foregroundStyle(VitalaColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.name).font(VitalaFont.bodyMedium(15))
                    if isCustom {
                        Text("Custom").font(VitalaFont.caption(10))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(VitalaColor.primary.opacity(0.15))
                            .foregroundStyle(VitalaColor.primary)
                            .clipShape(Capsule())
                    }
                }
                Text(item.servingSize).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
            Text("\(item.calories) kcal").font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.textPrimary)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.sm))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            if isCustom {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
