import SwiftUI
import Charts

/// Sleep tab home — last night, weekly stats, 7-night chart, and history
/// with edit and delete.
struct SleepView: View {
    @ObservedObject private var store = DataStore.shared
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var historyDate: Date = .now
    @State private var editingEntry: SleepEntry? = nil
    @State private var showingLog: Bool = false

    private var entriesNewestFirst: [SleepEntry] {
        store.allSleep.sorted { $0.wakeTime > $1.wakeTime }
    }

    private var lastNight: SleepEntry? { entriesNewestFirst.first }

    private var lastSevenDays: [SleepEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return entriesNewestFirst.filter { $0.wakeTime >= cutoff }
    }

    private var weekAvg: Double {
        guard !lastSevenDays.isEmpty else { return 0 }
        return lastSevenDays.reduce(0) { $0 + $1.hours } / Double(lastSevenDays.count)
    }

    private var sleepGoal: Double {
        profileStore.profile?.goals.sleepHours ?? 8.0
    }

    /// Nights in the last week that reached at least 90% of the goal.
    private var nightsOnTarget: Int {
        lastSevenDays.filter { $0.hours >= sleepGoal * 0.9 }.count
    }

    private var streak: Int {
        Insights.currentStreak(activeDays: Set(store.allSleep.map { Calendar.current.startOfDay(for: $0.wakeTime) }))
    }

    private var historyEntries: [SleepEntry] {
        store.allSleep
            .filter { Calendar.current.isDate($0.wakeTime, inSameDayAs: historyDate) }
            .sorted { $0.wakeTime > $1.wakeTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(
                    title: "Sleep",
                    subtitle: "Rest is the foundation.",
                    trailing: AnyView(
                        HeaderActionButton(title: "Log", accessibilityLabel: "Log sleep") {
                            showingLog = true
                        }
                    )
                )
                .padding(.top, VitalaSpacing.md)

                lastNightCard
                statsRow
                chartCard
                historySection
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingLog) {
            NavigationStack { SleepTrackerView() }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack { SleepTrackerView(editing: entry) }
        }
        .refreshable { await HealthKitService.shared.refreshHistory() }
        .task { await HealthKitService.shared.refreshHistory() }
    }

    // MARK: Last night

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Latest night", trailing: lastNight.map { relativeDay(for: $0.wakeTime) })

            if let n = lastNight {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: VitalaSpacing.md))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: VitalaSpacing.lg))
                layout {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(DashboardView.hoursText(n.hours))
                            .font(VitalaFont.title(34))
                            .foregroundStyle(VitalaColor.primary)
                        Text("\(n.bedTime.formatted(date: .omitted, time: .shortened)) to \(n.wakeTime.formatted(date: .omitted, time: .shortened))")
                            .font(VitalaFont.caption())
                            .foregroundStyle(VitalaColor.textSecondary)
                        Label(n.isFromHealth ? "From Apple Health" : n.quality.label,
                              systemImage: n.isFromHealth ? "heart.text.square" : n.quality.icon)
                            .font(VitalaFont.caption(13))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(VitalaColor.primary.opacity(0.12)))
                            .foregroundStyle(VitalaColor.primary)
                            .padding(.top, 2)
                    }
                    .accessibilityElement(children: .combine)
                    if !typeSize.isAccessibilitySize { Spacer() }
                    ProgressRingSingle(
                        progress: n.hours / max(sleepGoal, 0.1),
                        title: "of \(sleepGoal.formatted())h goal",
                        value: DashboardView.hoursText(n.hours),
                        color: VitalaColor.sleep,
                        lineWidth: 10
                    )
                    .frame(width: 110, height: 110)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title2)
                        .foregroundStyle(VitalaColor.sleep)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(VitalaColor.sleep.opacity(0.12)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No sleep logged yet")
                            .font(VitalaFont.bodyMedium(15))
                            .foregroundStyle(VitalaColor.textPrimary)
                        Text("Tap Log to record last night.")
                            .font(VitalaFont.caption(13))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .padding(.vertical, 6)
            }
        }
        .vitalaCard()
    }

    // MARK: Stats

    private var statsRow: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            statBox(value: weekAvg > 0 ? DashboardView.hoursText(weekAvg) : "—",
                    label: "7-day average",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: VitalaColor.sleep)
            statBox(value: "\(nightsOnTarget)/7",
                    label: "nights on target",
                    icon: "checkmark.seal.fill",
                    tint: VitalaColor.success)
            statBox(value: "\(streak)",
                    label: "nights logged in a row",
                    icon: "flame.fill",
                    tint: VitalaColor.coralText)
        }
    }

    private func statBox(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.14)))
                .accessibilityHidden(true)
            Text(value)
                .font(VitalaFont.title(20))
                .foregroundStyle(VitalaColor.textPrimary)
            Text(label)
                .font(VitalaFont.caption(11))
                .foregroundStyle(VitalaColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Last 7 nights", trailing: "Goal \(sleepGoal.formatted())h")

            if lastSevenDays.isEmpty {
                EmptyStateRow(text: "Log a few nights to see your trend.",
                              icon: "chart.bar.xaxis")
            } else {
                Chart {
                    ForEach(lastSevenDays.reversed()) { e in
                        BarMark(
                            x: .value("Night", e.wakeTime, unit: .day),
                            y: .value("Hours", e.hours)
                        )
                        .foregroundStyle(VitalaColor.sleep.gradient)
                        .cornerRadius(6)
                        .accessibilityLabel(e.wakeTime.formatted(.dateTime.weekday(.wide)))
                        .accessibilityValue(DashboardView.hoursText(e.hours))
                    }
                    RuleMark(y: .value("Goal", sleepGoal))
                        .foregroundStyle(VitalaColor.coralText.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        .accessibilityLabel("Goal")
                        .accessibilityValue("\(sleepGoal.formatted()) hours")
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
                .dailyChartAccessibility(DailyChartDescriptor(
                    title: "Hours slept", unit: "hours",
                    points: lastSevenDays.reversed().map { (Calendar.current.startOfDay(for: $0.wakeTime), $0.hours) },
                    goal: sleepGoal))
            }
        }
        .vitalaCard()
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History",
                          trailing: historyEntries.isEmpty ? nil : "\(historyEntries.count) \(historyEntries.count == 1 ? "entry" : "entries")")

            DateNavigator(date: $historyDate)

            if historyEntries.isEmpty {
                EmptyStateRow(text: "No sleep logged for this night.",
                              icon: "moon.zzz")
            } else {
                VStack(spacing: 8) {
                    ForEach(historyEntries) { e in
                        LogRow(icon: e.quality.icon,
                               tint: VitalaColor.sleep,
                               title: DashboardView.hoursText(e.hours),
                               subtitle: "\(e.bedTime.formatted(date: .omitted, time: .shortened)) to \(e.wakeTime.formatted(date: .omitted, time: .shortened)) · \(e.isFromHealth ? "Apple Health" : e.quality.label)",
                               noun: "sleep entry",
                               onEdit: e.isFromHealth ? nil : { editingEntry = e },
                               onDelete: e.isFromHealth ? nil : { delete(e) })
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func delete(_ entry: SleepEntry) {
        Task { try? await store.deleteSleep(entry) }
    }

    private func relativeDay(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "This morning" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
