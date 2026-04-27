import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var units: UnitsService
    @EnvironmentObject var appState: AppState

    /// Observe the local store so the dashboard re-renders whenever a meal,
    /// workout, water entry, etc. is logged from another screen.
    @ObservedObject private var store = FirestoreService.shared

    @State private var showingWater = false
    @State private var showingMindfulness = false

    // Computed totals — recalculated automatically when `store` publishes.
    private var todayWaterMl: Int {
        store.water
            .filter { Calendar.current.isDateInToday($0.loggedAt) }
            .reduce(0) { $0 + $1.amountMl }
    }
    private var todayMealKcal: Int {
        store.meals
            .filter { Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.totalCalories }
    }
    private var todayMindfulMin: Int {
        store.mindfulness
            .filter { Calendar.current.isDateInToday($0.completedAt) }
            .reduce(0) { $0 + $1.minutes }
    }
    private var lastSleepHours: Double {
        store.sleep.sorted { $0.wakeTime > $1.wakeTime }.first?.hours ?? 0
    }
    private var todayWorkouts: [WorkoutSession] {
        store.workouts.filter { Calendar.current.isDateInToday($0.startedAt) }
    }
    private var todayLocalActiveKcal: Int {
        todayWorkouts.reduce(0) { $0 + $1.caloriesBurned }
    }
    private var todayLocalExerciseMin: Int {
        todayWorkouts.reduce(0) { $0 + ($1.durationSeconds / 60) }
    }
    private var todayLocalWorkouts: Int { todayWorkouts.count }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hi"
        }
    }

    @State private var editingWorkout: WorkoutSession? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VitalaSpacing.lg) {
                    header
                    ringsCard
                    quickStats
                    todayLog
                    if !todayWorkouts.isEmpty {
                        todayActivityCard
                    }
                    streaksRow
                    Spacer().frame(height: VitalaSpacing.xl)
                }
                .padding(.horizontal, VitalaSpacing.lg)
            }
            .background(VitalaColor.background.ignoresSafeArea())
            .toolbar(.hidden)
            .refreshable { await health.refreshToday() }
            .task { await health.refreshToday() }
            .sheet(isPresented: $showingWater) {
                WaterTrackerView().presentationDetents([.medium, .large])
            }
            .sheet(item: $editingWorkout) { session in
                LogActivityView(editing: session)
            }
        }
    }

    /// Compact list of today's logged activities with tap-to-edit and swipe-to-delete.
    private var todayActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today's activity").font(VitalaFont.headline(18))
                Spacer()
                Text("\(todayWorkouts.count) logged")
                    .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            VStack(spacing: 8) {
                ForEach(todayWorkouts.sorted { $0.startedAt > $1.startedAt }) { session in
                    ActivityLogRow(session: session,
                                   onEdit: { editingWorkout = session },
                                   onDelete: { Task { try? await store.deleteWorkout(session) } })
                }
            }
        }
        .vitalaCard()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + ",").font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                Text(auth.profile?.displayName.split(separator: " ").first.map(String.init) ?? "Friend")
                    .font(VitalaFont.title(28))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            Spacer()
            ZStack {
                Circle().fill(VitalaColor.surface).frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                Image(systemName: "bell").foregroundStyle(VitalaColor.textPrimary)
            }
        }
        .padding(.top, VitalaSpacing.md)
    }

    private var ringsCard: some View {
        let goals = auth.profile?.goals ?? WellnessGoals()
        let s = health.todaySummary
        // Combine HealthKit's reading with locally-logged activity so custom
        // activities show up immediately even when HK isn't available.
        let displayKcal = max(s.activeKcal, todayLocalActiveKcal)
        let displayExMin = max(s.exerciseMinutes, todayLocalExerciseMin)

        let stepProg = min(Double(s.steps) / Double(goals.dailySteps), 1)
        let kcalProg = min(Double(displayKcal) / Double(max(goals.dailyCalories / 4, 1)), 1)
        let exProg = min(Double(displayExMin) / 30.0, 1)

        return VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack {
                Text("Today's rings").font(VitalaFont.headline(18))
                Spacer()
                Text(Date.now, style: .date).font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            HStack(spacing: VitalaSpacing.md) {
                ActivityRings(move: kcalProg, exercise: exProg, stand: stepProg)
                    .frame(width: 110, height: 110)

                VStack(alignment: .leading, spacing: 8) {
                    StatPill(label: "Move",     value: "\(displayKcal) kcal", tint: VitalaColor.ringMove)
                    StatPill(label: "Exercise", value: "\(displayExMin) min",  tint: VitalaColor.ringExercise)
                    StatPill(label: "Steps",    value: "\(s.steps.formatted())", tint: VitalaColor.ringStand)
                }
                Spacer(minLength: 0)
            }
            if todayLocalWorkouts > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(VitalaColor.primary)
                    Text("\(todayLocalWorkouts) \(todayLocalWorkouts == 1 ? "activity" : "activities") logged today")
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                .padding(.top, 4)
            }
        }
        .vitalaCard(padding: VitalaSpacing.md, corner: VitalaRadius.lg)
    }

    private var quickStats: some View {
        let s = health.todaySummary
        // Combine HealthKit reads with local logs so locally-logged sessions
        // surface immediately even when HK isn't available.
        let mindfulMins = max(s.mindfulMinutes, todayMindfulMin)
        let sleepHrs = max(s.sleepHours, lastSleepHours)
        let waterMl = max(s.waterMl, todayWaterMl)
        let goalWaterMl = auth.profile?.goals.dailyWaterMl ?? 2000

        // Compact volume value: "250 ml" / "2.0 L" / "8 oz" — without the unit suffix
        // (the unit goes in the card's `unit:` slot to keep typography tidy).
        let waterValueText: String
        let waterUnitText: String
        switch units.system {
        case .metric:
            if waterMl >= 1000 {
                waterValueText = String(format: "%.1f", Double(waterMl) / 1000.0)
                waterUnitText = "L of \(String(format: "%.1f", Double(goalWaterMl) / 1000.0))L"
            } else {
                waterValueText = "\(waterMl)"
                waterUnitText = "ml of \(goalWaterMl)"
            }
        case .imperial:
            let oz = Int((Double(waterMl) * 0.033814).rounded())
            let goalOz = Int((Double(goalWaterMl) * 0.033814).rounded())
            waterValueText = "\(oz)"
            waterUnitText = "oz of \(goalOz)"
        }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(icon: "drop.fill",
                       label: "Water",
                       value: waterValueText,
                       unit: waterUnitText,
                       tint: Color(red: 0.34, green: 0.62, blue: 0.86))
            MetricCard(icon: "heart.fill",
                       label: "Heart rate", value: s.heartRate.map { "\($0)" } ?? "—",
                       unit: "bpm", tint: VitalaColor.coral)
            MetricCard(icon: "moon.stars.fill",
                       label: "Sleep",
                       value: String(format: "%.1f", sleepHrs),
                       unit: "h",
                       tint: Color(red: 0.45, green: 0.46, blue: 0.78))
            MetricCard(icon: "leaf.fill",
                       label: "Mindful",
                       value: "\(mindfulMins)",
                       unit: "min",
                       tint: VitalaColor.sage)
        }
    }

    private var todayLog: some View {
        let waterColor = Color(red: 0.34, green: 0.62, blue: 0.86)
        let sleepColor = Color(red: 0.45, green: 0.46, blue: 0.78)

        let goalWater = auth.profile?.goals.dailyWaterMl ?? 2000
        let goalCal = auth.profile?.goals.dailyCalories ?? 2200
        let goalSleepHours = auth.profile?.goals.sleepHours ?? 8

        // Compact value strings (designed to fit a half-width tile).
        let waterCurrent = compactVolume(ml: todayWaterMl)
        let waterGoal = compactVolume(ml: goalWater)
        let waterValue = "\(waterCurrent) / \(waterGoal)"

        let mealValue = "\(todayMealKcal) / \(goalCal) kcal"

        let mindfulValue = todayMindfulMin == 0 ? "Take 5" : "\(todayMindfulMin) min today"
        let sleepValue: String = {
            guard lastSleepHours > 0 else { return "Tap to log" }
            let h = Int(lastSleepHours)
            let m = Int((lastSleepHours - Double(h)) * 60)
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }()

        let waterProgress = goalWater > 0 ? Double(todayWaterMl) / Double(goalWater) : 0
        let mealProgress  = goalCal   > 0 ? Double(todayMealKcal) / Double(goalCal)  : 0
        let mindfulProgress: Double = min(Double(todayMindfulMin) / 15.0, 1)
        let sleepProgress: Double   = goalSleepHours > 0 ? lastSleepHours / goalSleepHours : 0

        return VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Quick log")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                 GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                QuickLogButton(icon: "drop.fill", title: "Water",
                               value: waterValue, tint: waterColor,
                               progress: waterProgress) {
                    showingWater = true
                }
                QuickLogNavLink(icon: "fork.knife", title: "Meal",
                                value: mealValue, tint: VitalaColor.primary,
                                progress: mealProgress) {
                    AddMealView()
                }
                QuickLogNavLink(icon: "leaf.fill", title: "Mindful",
                                value: mindfulValue, tint: VitalaColor.sage,
                                progress: mindfulProgress) {
                    MindfulnessView()
                }
                QuickLogButton(icon: "moon.stars.fill", title: "Sleep",
                               value: sleepValue, tint: sleepColor,
                               progress: sleepProgress) {
                    appState.selectedTab = .sleep
                }
            }
        }
    }

    /// Volume formatted compactly so it fits in a half-width tile.
    /// e.g. 2000 ml → "2.0L", 250 ml → "250 ml"; imperial → "67oz" etc.
    private func compactVolume(ml: Int) -> String {
        switch units.system {
        case .metric:
            if ml >= 1000 {
                return String(format: "%.1fL", Double(ml) / 1000.0)
            }
            return "\(ml) ml"
        case .imperial:
            let oz = Double(ml) * 0.033814
            return String(format: "%.0foz", oz)
        }
    }

    private var streaksRow: some View {
        HStack(spacing: 12) {
            streakCard("3", "day streak", "flame.fill", tint: VitalaColor.coral)
            streakCard("87%", "weekly goal", "chart.line.uptrend.xyaxis", tint: VitalaColor.primary)
        }
    }

    private func streakCard(_ value: String, _ label: String, _ icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.15)).frame(width: 42, height: 42)
                Image(systemName: icon).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(VitalaFont.title(22))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(label).font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
        }
        .padding(VitalaSpacing.md)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}
