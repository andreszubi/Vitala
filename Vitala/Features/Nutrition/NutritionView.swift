import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = DataStore.shared

    @State private var date: Date = .now
    @State private var editingMeal: Meal? = nil
    @State private var addingMealType: Meal.MealType? = nil
    @State private var viewingFood: FoodDetail? = nil
    @State private var viewingMealType: Meal.MealType? = nil
    /// Opened once the food details sheet has closed.
    @State private var editAfterDetail: Meal? = nil

    /// A food tapped in a meal card, with the meal it belongs to.
    struct FoodDetail: Identifiable {
        let group: FoodGroup
        let meal: Meal
        var id: String { meal.id + group.id }
    }

    private var meals: [Meal] {
        store.allMeals
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    private var totalCalories: Int { meals.reduce(0) { $0 + $1.totalCalories } }
    private var goalCalories: Int { profileStore.profile?.goals.dailyCalories ?? 2200 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(
                    title: "Nutrition",
                    subtitle: "Eat well, with kindness.",
                    trailing: AnyView(
                        HeaderActionButton(title: "Log", accessibilityLabel: "Log a meal") {
                            addingMealType = Meal.MealType.suggested()
                        }
                    )
                )
                .padding(.top, VitalaSpacing.md)

                DateNavigator(date: $date)

                summaryCard
                macroBreakdown
                nutrientDetails
                mealsByType
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $addingMealType) { type in
            NavigationStack { AddMealView(initialType: type, forDate: date) }
        }
        .sheet(item: $editingMeal) { meal in
            NavigationStack { AddMealView(editing: meal) }
        }
        .sheet(item: $viewingMealType) { type in
            NavigationStack {
                MealNutritionSheet(type: type, date: date, meals: meals.filter { $0.type == type })
            }
        }
        .sheet(item: $viewingFood, onDismiss: {
            if let meal = editAfterDetail {
                editAfterDetail = nil
                editingMeal = meal
            }
        }) { detail in
            NavigationStack {
                FoodDetailSheet(item: detail.group.item, count: detail.group.count,
                                onEditMeal: detail.meal.isFromHealth ? nil : { editAfterDetail = detail.meal })
            }
            .presentationDetents([.medium, .large])
        }
        .refreshable { await HealthKitService.shared.refreshHistory() }
        .task { await HealthKitService.shared.refreshHistory() }
    }

    private var summaryCard: some View {
        let remaining = goalCalories - totalCalories
        let progress = goalCalories > 0 ? min(1.0, Double(totalCalories) / Double(goalCalories)) : 0
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VitalaSpacing.md))
            : AnyLayout(HStackLayout(spacing: VitalaSpacing.md))
        return layout {
            ProgressRingSingle(progress: progress, title: "kcal eaten", value: "\(totalCalories)",
                               color: VitalaColor.primary, lineWidth: 14)
                .frame(width: 124, height: 124)
            VStack(alignment: .leading, spacing: 6) {
                Text(dayLabel).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Text("\(totalCalories.formatted()) / \(goalCalories.formatted()) kcal")
                    .font(VitalaFont.headline(20))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(statusText(remaining: remaining))
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(meals.isEmpty ? VitalaColor.textSecondary : VitalaColor.success)
            }
            Spacer(minLength: 0)
        }
        .vitalaCard()
    }

    private func statusText(remaining: Int) -> String {
        if meals.isEmpty { return "Nothing logged yet" }
        if remaining >= 0 { return "\(remaining.formatted()) kcal left today" }
        return "\((-remaining).formatted()) kcal over your target"
    }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today's intake" }
        if cal.isDateInYesterday(date) { return "Yesterday's intake" }
        return "Intake on \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private var macroBreakdown: some View {
        let p = meals.reduce(0.0) { $0 + $1.totalProtein }
        let c = meals.reduce(0.0) { $0 + $1.totalCarbs }
        let f = meals.reduce(0.0) { $0 + $1.totalFat }
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            macroBox("Protein", p, VitalaColor.coral)
            macroBox("Carbs", c, VitalaColor.sage)
            macroBox("Fat", f, Color(red: 0.93, green: 0.70, blue: 0.30))
        }
    }

    private func macroBox(_ label: String, _ grams: Double, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Capsule().fill(tint).frame(width: 20, height: 6)
                .accessibilityHidden(true)
            Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            Text("\(Int(grams.rounded())) g").font(VitalaFont.title(20)).foregroundStyle(VitalaColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    /// Fiber, sugar, saturated fat and sodium for the day, against the FDA
    /// daily values where there is one.
    private var nutrientDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "More nutrients")
            NutrientBar(label: "Fiber", amount: meals.reduce(0) { $0 + $1.totalFiber }, unit: "g",
                        dailyValue: 28, tint: VitalaColor.sage)
            NutrientBar(label: "Sugar", amount: Meal.listedTotal(meals.map(\.totalSugar)), unit: "g",
                        dailyValue: nil, tint: VitalaColor.coral)
            NutrientBar(label: "Saturated fat", amount: Meal.listedTotal(meals.map(\.totalSaturatedFat)), unit: "g",
                        dailyValue: 20, tint: Color(red: 0.93, green: 0.70, blue: 0.30))
            NutrientBar(label: "Unsaturated fat", amount: Meal.listedTotal(meals.map(\.totalUnsaturatedFat)), unit: "g",
                        dailyValue: nil, tint: VitalaColor.primary)
            NutrientBar(label: "Sodium", amount: Meal.listedTotal(meals.map(\.totalSodiumMg)), unit: "mg",
                        dailyValue: 2300, tint: VitalaColor.water)
            Group {
                if meals.contains(where: \.hasUnlistedNutrients) {
                    Text("Some foods don't list sugar, the kinds of fat or sodium, so these totals may be low.")
                }
                Text("Daily values from the FDA, for a 2,000-calorie diet.")
            }
            .font(VitalaFont.caption(12))
            .foregroundStyle(VitalaColor.textSecondary)
        }
        .vitalaCard()
    }

    private var mealsByType: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.md) {
            ForEach(Meal.MealType.allCases) { type in
                MealSection(
                    type: type,
                    meals: meals.filter { $0.type == type },
                    onAdd: { addingMealType = type },
                    onEdit: { editingMeal = $0 },
                    onDelete: { meal in Task { try? await store.deleteMeal(meal) } },
                    onSelectFood: { meal, group in viewingFood = FoodDetail(group: group, meal: meal) },
                    onShowNutrition: { viewingMealType = type }
                )
            }
        }
    }
}

extension Meal.MealType {
    /// A sensible default for the time of day.
    static func suggested(at date: Date = .now) -> Meal.MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 17..<22: .dinner
        default: .snack
        }
    }
}

private struct MealSection: View {
    let type: Meal.MealType
    let meals: [Meal]
    let onAdd: () -> Void
    let onEdit: (Meal) -> Void
    let onDelete: (Meal) -> Void
    let onSelectFood: (Meal, FoodGroup) -> Void
    let onShowNutrition: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Opens the section's nutrition once something is logged.
                Button(action: onShowNutrition) {
                    HStack(spacing: 6) {
                        Label(type.label, systemImage: type.icon)
                            .font(VitalaFont.headline(17))
                            .foregroundStyle(VitalaColor.textPrimary)
                            .labelStyle(TintedIconLabelStyle())
                        if !meals.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VitalaColor.muted)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(meals.isEmpty)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint(meals.isEmpty ? "" : "Shows \(type.label.lowercased()) nutrition")
                Spacer()
                Text("\(meals.reduce(0) { $0 + $1.totalCalories }) kcal")
                    .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(VitalaColor.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add to \(type.label.lowercased())")
            }
            if meals.isEmpty {
                Text("Nothing logged")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surfaceCard()
            } else {
                ForEach(meals) { meal in
                    MealCard(meal: meal,
                             onEdit: meal.isFromHealth ? nil : { onEdit(meal) },
                             onDelete: meal.isFromHealth ? nil : { onDelete(meal) },
                             onSelectFood: { onSelectFood(meal, $0) })
                }
            }
        }
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(VitalaColor.primary)
            configuration.title
        }
    }
}

/// A logged meal. Each food opens its nutrition details; the meal itself
/// is edited or deleted from the "More options" menu.
private struct MealCard: View {
    let meal: Meal
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onSelectFood: (FoodGroup) -> Void

    var body: some View {
        EditableRow(noun: "meal", onEdit: onEdit, onDelete: onDelete, tapEdits: false) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meal.date, style: .time)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                    if meal.isFromHealth {
                        Label("Apple Health", systemImage: "heart.text.square")
                            .font(VitalaFont.caption(12))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    Spacer()
                    Text("\(meal.totalCalories) kcal")
                        .font(VitalaFont.bodyMedium(14))
                        .foregroundStyle(VitalaColor.textPrimary)
                }
                .accessibilityElement(children: .combine)
                ForEach(FoodGroup.grouping(meal.items)) { group in
                    Button { onSelectFood(group) } label: { FoodLine(group: group) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows nutrition details")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

/// One food in a meal card: full name with brand, the amount eaten, energy.
private struct FoodLine: View {
    let group: FoodGroup

    private var item: FoodItem { group.item }
    private var amount: String {
        group.count > 1 ? "\(group.count) × \(item.servingSize)" : item.servingSize
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.displayIcon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 20)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fullName)
                    .font(VitalaFont.body(14))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(amount)
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("\(item.calories * group.count) kcal")
                .font(VitalaFont.caption(12))
                .foregroundStyle(VitalaColor.textSecondary)
                .padding(.top, 2)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VitalaColor.muted)
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A day's total for one nutrient, with a bar against its daily value.
private struct NutrientBar: View {
    let label: String
    /// Nil when nothing eaten that day lists this nutrient.
    let amount: Double?
    let unit: String
    let dailyValue: Double?
    let tint: Color

    private var summary: String {
        guard let amount else { return "Not listed" }
        return dailyValue.map { "\(text(amount)) of \(text($0))" } ?? text(amount)
    }

    private func text(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...(unit == "mg" ? 0 : 1))))) \(unit)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Spacer()
                Text(summary)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            if let dailyValue {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.2))
                        Capsule().fill(tint).frame(width: geo.size.width * min(1, (amount ?? 0) / dailyValue))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            } else {
                // Same height as rows with a bar, so the rows line up and each
                // stays a comfortable target for VoiceOver.
                Color.clear.frame(height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(amount == nil || dailyValue == nil ? summary : summary + " daily value")
    }
}

/// Identical foods in a meal shown as one line with a count.
struct FoodGroup: Identifiable {
    let item: FoodItem
    let count: Int
    var id: String { FoodGroup.key(item) }

    static func key(_ item: FoodItem) -> String {
        "\(item.name)|\(item.servingSize)|\(item.calories)"
    }

    static func grouping(_ items: [FoodItem]) -> [FoodGroup] {
        var order: [String] = []
        var counts: [String: (FoodItem, Int)] = [:]
        for item in items {
            let k = key(item)
            if let existing = counts[k] {
                counts[k] = (existing.0, existing.1 + 1)
            } else {
                order.append(k)
                counts[k] = (item, 1)
            }
        }
        return order.compactMap { counts[$0].map { FoodGroup(item: $0.0, count: $0.1) } }
    }
}

struct FoodRow: View {
    let item: FoodItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.displayIcon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.10)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fullName).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.servingSize).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 8)
            Text("\(item.calories) kcal").font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.textPrimary)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .frame(minHeight: 44)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
