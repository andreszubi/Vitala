import SwiftUI
import Charts

/// Trends across everything the user logs, plus steps from Apple Health.
struct ProgressDashboardView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var units: UnitsService
    @ObservedObject private var store = DataStore.shared

    @State private var range: Range = .week
    @State private var steps: [Date: Int] = [:]

    enum Range: String, CaseIterable, Identifiable {
        case week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: "7 days"
            case .month: "30 days"
            }
        }
        var days: Int { self == .week ? 7 : 30 }
    }

    private var goals: WellnessGoals { profileStore.profile?.goals ?? WellnessGoals() }
    private var days: [Date] { Insights.lastDays(range.days) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { r in
                        Text(r.label).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, VitalaSpacing.sm)

                consistencyCard

                TrendCard(title: "Steps", unit: "steps", color: VitalaColor.ringStand,
                          points: days.map { ($0, Double(steps[$0] ?? 0)) },
                          goal: Double(goals.dailySteps),
                          emptyMessage: health.isAuthorized
                            ? "No steps recorded in Apple Health for this period."
                            : "Connect Apple Health in your profile to see steps.",
                          format: { Int($0).formatted() })

                TrendCard(title: "Exercise", unit: "min", color: VitalaColor.ringExercise,
                          points: series(store.workouts, date: \.startedAt) { Double($0.durationSeconds) / 60 },
                          goal: Double(goals.dailyExerciseMinutes),
                          emptyMessage: "Log a workout to start your trend.",
                          format: { "\(Int($0)) min" })

                TrendCard(title: "Food energy", unit: "kcal", color: VitalaColor.primary,
                          points: series(store.allMeals, date: \.date) { Double($0.totalCalories) },
                          goal: Double(goals.dailyCalories),
                          emptyMessage: "Log meals to see your intake over time.",
                          format: { "\(Int($0).formatted()) kcal" })

                TrendCard(title: "Water", unit: units.volumeUnitLabel(), color: VitalaColor.water,
                          points: series(store.water, date: \.loggedAt) { units.system == .metric ? Double($0.amountMl) : Double($0.amountMl) * 0.033814 },
                          goal: units.system == .metric ? Double(goals.dailyWaterMl) : Double(goals.dailyWaterMl) * 0.033814,
                          emptyMessage: "Log water to see your hydration trend.",
                          format: { "\(Int($0.rounded())) \(units.volumeUnitLabel())" })

                TrendCard(title: "Sleep", unit: "h", color: VitalaColor.sleep,
                          points: series(store.allSleep, date: \.wakeTime) { $0.hours },
                          goal: goals.sleepHours,
                          emptyMessage: "Log your nights to see sleep trends.",
                          format: { DashboardView.hoursText($0) })

                TrendCard(title: "Mindful minutes", unit: "min", color: VitalaColor.mindful,
                          points: series(store.mindfulness, date: \.completedAt) { Double($0.minutes) },
                          goal: Double(goals.dailyMindfulMinutes),
                          emptyMessage: "Try a session to start a calm streak.",
                          format: { "\(Int($0)) min" })
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: range) {
            let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
            steps = await health.dailySteps(from: days.first ?? .now, to: end)
        }
    }

    private func series<T>(_ items: [T], date: (T) -> Date, value: (T) -> Double) -> [(Date, Double)] {
        let totals = Insights.dailyTotals(items, days: days, date: date, value: value)
        return days.map { ($0, totals[$0] ?? 0) }
    }

    // MARK: Consistency

    private var consistencyCard: some View {
        let grid = Insights.lastDays(28)
        let active = Insights.activeDays(store.snapshot)
        let activeCount = grid.filter(active.contains).count
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Consistency", trailing: "\(activeCount) of 28 days")
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(grid, id: \.self) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(active.contains(day) ? VitalaColor.primary : VitalaColor.primary.opacity(0.12))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if Calendar.current.isDateInToday(day) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(VitalaColor.textPrimary, lineWidth: 1.5)
                            }
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Days with any log, last 4 weeks")
            .accessibilityValue("Active on \(activeCount) of 28 days")
            Text("Each square is a day you logged anything — water, a meal, a workout, sleep or a mindful pause.")
                .font(VitalaFont.caption(12))
                .foregroundStyle(VitalaColor.textSecondary)
        }
        .vitalaCard()
    }
}

/// One metric over time: average, bar chart, and optional goal line.
private struct TrendCard: View {
    let title: String
    let unit: String
    let color: Color
    let points: [(Date, Double)]
    var goal: Double? = nil
    let emptyMessage: String
    let format: (Double) -> String

    private var hasData: Bool { points.contains { $0.1 > 0 } }
    private var average: Double {
        let logged = points.filter { $0.1 > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.1 } / Double(logged.count)
    }
    private var daysOnGoal: Int {
        guard let goal else { return 0 }
        return points.filter { $0.1 >= goal }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, trailing: hasData ? "avg \(format(average))" : nil)
            if hasData {
                Chart {
                    ForEach(points, id: \.0) { point in
                        BarMark(x: .value("Day", point.0, unit: .day),
                                y: .value(title, point.1))
                            .foregroundStyle(color.gradient)
                            .cornerRadius(points.count > 10 ? 2 : 5)
                            .accessibilityLabel(point.0.formatted(.dateTime.weekday(.wide).month().day()))
                            .accessibilityValue(format(point.1))
                    }
                    if let goal {
                        RuleMark(y: .value("Goal", goal))
                            .foregroundStyle(VitalaColor.textSecondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .accessibilityLabel("Goal")
                            .accessibilityValue(format(goal))
                    }
                }
                .chartXAxis {
                    if points.count <= 7 {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                }
                .frame(height: 160)
                .dailyChartAccessibility(DailyChartDescriptor(title: title, unit: unit, points: points, goal: goal))

                if goal != nil {
                    Text("Goal met on \(daysOnGoal) of \(points.count) days")
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            } else {
                EmptyStateRow(text: emptyMessage, icon: "chart.bar.xaxis")
            }
        }
        .vitalaCard()
    }
}
