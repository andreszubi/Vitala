import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @ObservedObject private var store = DataStore.shared

    @State private var date: Date = .now
    @State private var editingMeal: Meal? = nil
    @State private var addingMealType: Meal.MealType? = nil

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

    private var mealsByType: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.md) {
            ForEach(Meal.MealType.allCases) { type in
                MealSection(
                    type: type,
                    meals: meals.filter { $0.type == type },
                    onAdd: { addingMealType = type },
                    onEdit: { editingMeal = $0 },
                    onDelete: { meal in Task { try? await store.deleteMeal(meal) } }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(type.label, systemImage: type.icon)
                    .font(VitalaFont.headline(17))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .labelStyle(TintedIconLabelStyle())
                    .accessibilityAddTraits(.isHeader)
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
                             onDelete: meal.isFromHealth ? nil : { onDelete(meal) })
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

private struct MealCard: View {
    let meal: Meal
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        EditableRow(noun: "meal", onEdit: onEdit, onDelete: onDelete) {
            VStack(alignment: .leading, spacing: 6) {
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
                ForEach(FoodGroup.grouping(meal.items)) { group in
                    HStack(spacing: 8) {
                        Image(systemName: group.item.icon)
                            .foregroundStyle(VitalaColor.primary)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(group.count > 1 ? "\(group.item.name) × \(group.count)" : group.item.name)
                            .font(VitalaFont.body(14))
                            .foregroundStyle(VitalaColor.textPrimary)
                        Spacer()
                        Text("\(group.item.calories * group.count) kcal")
                            .font(VitalaFont.caption(12))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
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
            Image(systemName: item.icon)
                .foregroundStyle(VitalaColor.primary)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VitalaColor.primary.opacity(0.10)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(VitalaFont.bodyMedium(15)).foregroundStyle(VitalaColor.textPrimary)
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
