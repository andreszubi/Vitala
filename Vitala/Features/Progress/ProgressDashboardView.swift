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
                          goal: Double(goals.dailyCalories), goalIsLimit: true,
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

                MoodCard(entries: store.journal, days: days)
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
    /// True when the goal is a ceiling to stay under (food energy) rather
    /// than a target to reach.
    var goalIsLimit = false
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
        return DailyChartDescriptor.daysOnGoal(points, goal: goal, isLimit: goalIsLimit)
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
                .dailyChartAccessibility(DailyChartDescriptor(title: title, unit: unit, points: points, goal: goal,
                                                              goalIsLimit: goalIsLimit))

                if goal != nil {
                    Text(goalIsLimit ? "Within target on \(daysOnGoal) of \(points.count) days"
                                     : "Goal met on \(daysOnGoal) of \(points.count) days")
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

/// Journal moods over time: each day's mood on a scale from low to great,
/// and the moods chosen most often.
private struct MoodCard: View {
    let entries: [JournalEntry]
    let days: [Date]

    private var moodDays: [MoodTrends.Day] { MoodTrends.days(entries, in: days) }
    private var counts: [MoodTrends.Count] { MoodTrends.counts(entries, in: days) }
    private var total: Int { counts.reduce(0) { $0 + $1.count } }

    /// "Mostly calm. Lighter than the 7 days before."
    private var summary: String {
        var parts: [String] = []
        if let headline = MoodTrends.headline(counts) { parts.append(headline) }
        if let change = MoodTrends.change(entries, in: days) { parts.append(change.sentence(days: days.count)) }
        return parts.joined(separator: " ")
    }

    private var spokenSummary: String {
        guard !moodDays.isEmpty else { return "No entries yet." }
        let each = counts.map { "\($0.mood.label) \($0.count)" }.joined(separator: ", ")
        return "\(total) \(total == 1 ? "entry" : "entries") on \(moodDays.count) of \(days.count) days. \(summary) \(each)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Mood", trailing: total > 0 ? "\(total) \(total == 1 ? "entry" : "entries")" : nil)
            if moodDays.isEmpty {
                EmptyStateRow(text: "Write in your journal to see how your mood moves over time.", icon: "book.closed")
            } else {
                chart
                if !summary.isEmpty {
                    Text(summary)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 8) {
                    ForEach(counts.prefix(4)) { count in
                        MoodCountRow(count: count, total: total)
                    }
                }
                Text("From the mood you pick in each journal entry. A day with several entries shows their average.")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .vitalaCard()
    }

    private var chart: some View {
        Chart {
            ForEach(moodDays, id: \.date) { day in
                LineMark(x: .value("Day", day.date, unit: .day), y: .value("Mood", day.score))
                    .foregroundStyle(VitalaColor.mindful.opacity(0.55))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Day", day.date, unit: .day), y: .value("Mood", day.score))
                    .foregroundStyle(VitalaColor.mindful)
                    .symbolSize(days.count > 10 ? 40 : 90)
            }
        }
        .chartYScale(domain: 0.5...5.5)
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 3, 5]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let score = value.as(Int.self) {
                        Text(score == 1 ? "Low" : score == 3 ? "Okay" : "Great")
                    }
                }
            }
        }
        .chartXScale(domain: (days.first ?? .now)...(Calendar.current.date(byAdding: .day, value: 1, to: days.last ?? .now) ?? .now))
        .chartXAxis {
            if days.count <= 7 {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            } else {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        }
        .frame(height: 150)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood chart")
        .accessibilityValue(spokenSummary)
        .accessibilityChartDescriptor(MoodChartDescriptor(days: moodDays, summary: spokenSummary))
    }
}

/// One mood, how many entries chose it, and its share as a bar.
private struct MoodCountRow: View {
    let count: MoodTrends.Count
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: count.mood.icon)
                .foregroundStyle(VitalaColor.mindful)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(count.mood.label)
                .font(VitalaFont.body(15))
                .foregroundStyle(VitalaColor.textPrimary)
                .frame(minWidth: 84, alignment: .leading)
            GeometryReader { geo in
                Capsule()
                    .fill(VitalaColor.mindful.opacity(0.18))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(VitalaColor.mindful)
                            .frame(width: max(6, geo.size.width * CGFloat(count.count) / CGFloat(max(total, 1))))
                    }
            }
            .frame(height: 6)
            Text("\(count.count)")
                .font(VitalaFont.bodyMedium(14))
                .monospacedDigit()
                .foregroundStyle(VitalaColor.textSecondary)
                .frame(minWidth: 22, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count.mood.label)
        .accessibilityValue("\(count.count) of \(total) \(total == 1 ? "entry" : "entries")")
    }
}

/// The mood chart as an Audio Graph: one point for each day with an entry.
private struct MoodChartDescriptor: AXChartDescriptorRepresentable {
    let days: [MoodTrends.Day]
    let summary: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let labels = days.map { $0.date.formatted(.dateTime.weekday(.abbreviated).month().day()) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: labels)
        let yAxis = AXNumericDataAxisDescriptor(title: "Mood", range: 1...5, gridlinePositions: [1, 3, 5]) {
            MoodTrends.word(for: $0)
        }
        let series = AXDataSeriesDescriptor(name: "Mood", isContinuous: true,
                                            dataPoints: zip(labels, days).map { AXDataPoint(x: $0, y: $1.score) })
        return AXChartDescriptor(title: "Mood", summary: summary, xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }
}
