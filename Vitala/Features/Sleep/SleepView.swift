import SwiftUI
import Charts

/// Sleep tab home — last night, weekly stats, 7-night chart, and full history
/// with tap-to-edit / swipe-to-delete.
struct SleepView: View {
    @ObservedObject private var store = FirestoreService.shared
    @EnvironmentObject var auth: AuthService

    @State private var historyDate: Date = .now
    @State private var editingEntry: SleepEntry? = nil
    @State private var showingLog: Bool = false

    private var entriesNewestFirst: [SleepEntry] {
        store.sleep.sorted { $0.wakeTime > $1.wakeTime }
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
        auth.profile?.goals.sleepHours ?? 8.0
    }

    private var consistency: Double {
        // Simple "consistency" score: fraction of last 7 nights that hit at least
        // 80% of the sleep goal.
        guard !lastSevenDays.isEmpty else { return 0 }
        let met = lastSevenDays.filter { $0.hours >= sleepGoal * 0.8 }.count
        return Double(met) / 7.0
    }

    private var historyEntries: [SleepEntry] {
        store.sleep
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
                        Button {
                            showingLog = true
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

                lastNightCard
                statsRow
                chartCard
                historySection
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .sheet(isPresented: $showingLog) {
            NavigationStack { SleepTrackerView() }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack { SleepTrackerView(editing: entry) }
        }
    }

    // MARK: Last night

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack {
                Text("Last night").font(VitalaFont.headline(18))
                Spacer()
                if let n = lastNight {
                    Text(relativeDay(for: n.wakeTime))
                        .font(VitalaFont.caption())
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            if let n = lastNight {
                HStack(alignment: .center, spacing: VitalaSpacing.lg) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedHours(n.hours))
                            .font(VitalaFont.title(34))
                            .foregroundStyle(VitalaColor.primary)
                        Text("\(n.bedTime.formatted(date: .omitted, time: .shortened)) → \(n.wakeTime.formatted(date: .omitted, time: .shortened))")
                            .font(VitalaFont.caption())
                            .foregroundStyle(VitalaColor.textSecondary)
                        Label(n.quality.label, systemImage: n.quality.icon)
                            .font(VitalaFont.caption(13))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(VitalaColor.primary.opacity(0.12))
                            .foregroundStyle(VitalaColor.primary)
                            .clipShape(Capsule())
                            .padding(.top, 2)
                    }
                    Spacer()
                    sleepGoalRing(hours: n.hours)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(VitalaColor.primary)
                        .frame(width: 50, height: 50)
                        .background(VitalaColor.primary.opacity(0.12))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No sleep logged yet")
                            .font(VitalaFont.bodyMedium(15))
                        Text("Tap **Log** to record last night.")
                            .font(VitalaFont.caption(13))
                            .foregroundStyle(VitalaColor.textSecondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .vitalaCard()
    }

    private func sleepGoalRing(hours: Double) -> some View {
        let progress = min(1, hours / max(sleepGoal, 0.1))
        return ProgressRingSingle(
            progress: progress,
            title: "of \(String(format: "%.0fh", sleepGoal)) goal",
            value: formattedHours(hours),
            color: VitalaColor.primary,
            lineWidth: 10
        )
        .frame(width: 110, height: 110)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statBox(value: formattedHours(weekAvg),
                    label: "7-day average",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: VitalaColor.primary)
            statBox(value: "\(Int(consistency * 100))%",
                    label: "consistency",
                    icon: "checkmark.seal.fill",
                    tint: VitalaColor.success)
            statBox(value: "\(streakDays())",
                    label: "night streak",
                    icon: "flame.fill",
                    tint: VitalaColor.coral)
        }
    }

    private func statBox(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Circle().fill(tint.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(VitalaFont.title(20))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(VitalaFont.caption(11))
                .foregroundStyle(VitalaColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard(padding: 12)
    }

    private func streakDays() -> Int {
        var streak = 0
        var date = Calendar.current.startOfDay(for: .now)
        let dates = Set(store.sleep.map { Calendar.current.startOfDay(for: $0.wakeTime) })
        while dates.contains(date) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    // MARK: Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack {
                Text("Last 7 nights").font(VitalaFont.headline(18))
                Spacer()
                Text("Goal: \(String(format: "%.0fh", sleepGoal))")
                    .font(VitalaFont.caption())
                    .foregroundStyle(VitalaColor.textSecondary)
            }

            if lastSevenDays.isEmpty {
                EmptyStateRow(text: "Log a few nights to see your trend.",
                              icon: "chart.bar.xaxis")
            } else {
                Chart {
                    ForEach(lastSevenDays.reversed()) { e in
                        BarMark(
                            x: .value("Day", e.wakeTime, unit: .day),
                            y: .value("Hours", e.hours)
                        )
                        .foregroundStyle(VitalaColor.primary.gradient)
                        .cornerRadius(6)
                    }
                    RuleMark(y: .value("Goal", sleepGoal))
                        .foregroundStyle(VitalaColor.coral.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(VitalaFont.caption(10))
                                .foregroundStyle(VitalaColor.coral)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
            }
        }
        .vitalaCard()
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("History").font(VitalaFont.headline(18))
                Spacer()
                if !historyEntries.isEmpty {
                    Text("\(historyEntries.count) entry\(historyEntries.count == 1 ? "" : "ies")")
                        .font(VitalaFont.caption())
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }

            DateNavigator(date: $historyDate)

            if historyEntries.isEmpty {
                EmptyStateRow(text: "No sleep logged for this night.",
                              icon: "moon.zzz.fill")
            } else {
                VStack(spacing: 8) {
                    ForEach(historyEntries) { e in
                        SleepLogRow(
                            entry: e,
                            onEdit: { editingEntry = e },
                            onDelete: { Task { try? await store.deleteSleep(e) } }
                        )
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func formattedHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func relativeDay(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "This morning" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Row

struct SleepLogRow: View {
    let entry: SleepEntry
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var hoursLabel: String {
        let h = Int(entry.hours)
        let m = Int((entry.hours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.45, green: 0.46, blue: 0.78).opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: entry.quality.icon)
                    .foregroundStyle(Color(red: 0.45, green: 0.46, blue: 0.78))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(hoursLabel)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text("\(entry.bedTime.formatted(date: .omitted, time: .shortened)) → \(entry.wakeTime.formatted(date: .omitted, time: .shortened)) · \(entry.quality.label)")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitalaColor.muted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .padding(10)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .contextMenu {
            Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}
