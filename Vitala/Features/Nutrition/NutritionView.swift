import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var auth: AuthService
    @ObservedObject private var store = FirestoreService.shared

    @State private var date: Date = .now
    @State private var editingMeal: Meal? = nil
    @State private var showingAddMeal: Bool = false

    private var meals: [Meal] {
        store.meals
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    private var totalCalories: Int { meals.reduce(0) { $0 + $1.totalCalories } }
    private var goalCalories: Int { auth.profile?.goals.dailyCalories ?? 2200 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(
                    title: "Nutrition",
                    subtitle: "Eat well, with kindness.",
                    trailing: AnyView(
                        Button {
                            showingAddMeal = true
                        } label: {
                            Label("Log", systemImage: "plus.circle.fill")
                                .font(VitalaFont.bodyMedium(15))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(VitalaColor.primary.opacity(0.12))
                                .foregroundStyle(VitalaColor.primary)
                                .clipShape(Capsule())
                        }
                    )
                )
                .padding(.top, VitalaSpacing.md)

                DateNavigator(date: $date)

                summaryCard
                macroBreakdown
                mealsByType
                Spacer().frame(height: VitalaSpacing.xl)
            }
            .padding(.horizontal, VitalaSpacing.lg)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .sheet(isPresented: $showingAddMeal) {
            NavigationStack { AddMealView(forDate: date) }
        }
        .sheet(item: $editingMeal) { meal in
            NavigationStack { AddMealView(editing: meal) }
        }
    }

    private var summaryCard: some View {
        let remaining = max(0, goalCalories - totalCalories)
        let progress = goalCalories > 0 ? min(1.0, Double(totalCalories) / Double(goalCalories)) : 0
        return HStack(spacing: VitalaSpacing.md) {
            ProgressRingSingle(progress: progress, title: "kcal", value: "\(totalCalories)",
                               color: VitalaColor.primary, lineWidth: 14)
                .frame(width: 130, height: 130)
            VStack(alignment: .leading, spacing: 6) {
                Text(dayLabel).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                Text("\(totalCalories) / \(goalCalories) kcal")
                    .font(VitalaFont.headline(20))
                Text(meals.isEmpty ? "Nothing logged yet" : "\(remaining) remaining")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(meals.isEmpty ? VitalaColor.textSecondary : VitalaColor.success)
            }
            Spacer()
        }
        .vitalaCard()
    }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today's intake" }
        if cal.isDateInYesterday(date) { return "Yesterday's intake" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return "Intake on \(f.string(from: date))"
    }

    private var macroBreakdown: some View {
        let p = meals.reduce(0.0) { $0 + $1.totalProtein }
        let c = meals.reduce(0.0) { $0 + $1.totalCarbs }
        let f = meals.reduce(0.0) { $0 + $1.totalFat }
        return HStack(spacing: 12) {
            macroBox("Protein", "\(Int(p))g", VitalaColor.coral)
            macroBox("Carbs",   "\(Int(c))g", VitalaColor.sage)
            macroBox("Fat",     "\(Int(f))g", Color(red: 0.95, green: 0.74, blue: 0.36))
        }
    }

    private func macroBox(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            Text(value).font(VitalaFont.title(20))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 14)
    }

    private var mealsByType: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            ForEach(Meal.MealType.allCases) { type in
                let typeMeals = meals.filter { $0.type == type }
                MealSection(
                    type: type,
                    meals: typeMeals,
                    onEdit: { editingMeal = $0 },
                    onDelete: { meal in Task { try? await store.deleteMeal(meal) } }
                )
            }
        }
    }
}

private struct MealSection: View {
    let type: Meal.MealType
    let meals: [Meal]
    let onEdit: (Meal) -> Void
    let onDelete: (Meal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: type.icon).foregroundStyle(VitalaColor.primary)
                Text(type.label).font(VitalaFont.headline(17))
                Spacer()
                Text("\(meals.reduce(0) { $0 + $1.totalCalories }) kcal")
                    .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            if meals.isEmpty {
                Text("Nothing logged")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VitalaColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
            } else {
                ForEach(meals) { meal in
                    MealCard(
                        meal: meal,
                        onEdit: { onEdit(meal) },
                        onDelete: { onDelete(meal) }
                    )
                }
            }
        }
    }
}

private struct MealCard: View {
    let meal: Meal
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meal.date, style: .time)
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                Spacer()
                Text("\(meal.totalCalories) kcal")
                    .font(VitalaFont.bodyMedium(14))
                    .foregroundStyle(VitalaColor.textPrimary)
                Menu {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitalaColor.muted)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                // Enumerated index is used as the SwiftUI identity to defend
                // against legacy meals that may have duplicate FoodItem ids.
                ForEach(Array(meal.items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundStyle(VitalaColor.primary)
                            .frame(width: 18)
                        Text(item.name)
                            .font(VitalaFont.body(14))
                            .foregroundStyle(VitalaColor.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(item.calories) kcal")
                            .font(VitalaFont.caption(12))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

struct FoodRow: View {
    let item: FoodItem
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(VitalaColor.sage.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: item.icon).foregroundStyle(VitalaColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(VitalaFont.bodyMedium(15))
                Text(item.servingSize).font(VitalaFont.caption(13)).foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
            Text("\(item.calories) kcal").font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.textPrimary)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.sm))
    }
}
