import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @EnvironmentObject var health: HealthKitService
    @EnvironmentObject var units: UnitsService
    @EnvironmentObject var appState: AppState
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Observe the local store so the dashboard re-renders whenever a meal,
    /// workout, water entry, etc. is logged from another screen.
    @ObservedObject private var store = DataStore.shared

    @AppStorage("vitala.healthPromptDismissed") private var healthPromptDismissed = false
    @State private var showingWater = false
    @State private var showingMeal = false
    @State private var showingSleep = false
    @State private var editingWorkout: WorkoutSession? = nil

    private var goals: WellnessGoals { profileStore.profile?.goals ?? WellnessGoals() }

    // Today's local totals — recalculated whenever `store` publishes.
    private func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }
    private var todayWaterMl: Int {
        store.water.filter { isToday($0.loggedAt) }.reduce(0) { $0 + $1.amountMl }
    }
    private var todayMealKcal: Int {
        store.meals.filter { isToday($0.date) }.reduce(0) { $0 + $1.totalCalories }
    }
    private var todayMindfulMin: Int {
        store.mindfulness.filter { isToday($0.completedAt) }.reduce(0) { $0 + $1.minutes }
    }
    private var lastNight: SleepEntry? {
        store.sleep.filter { isToday($0.wakeTime) }.max { $0.wakeTime < $1.wakeTime }
    }
    private var todayWorkouts: [WorkoutSession] {
        store.workouts.filter { isToday($0.startedAt) }.sorted { $0.startedAt > $1.startedAt }
    }

    // Combine HealthKit with local logs so entries made in Vitala count
    // immediately, without double-counting what Vitala itself wrote to Health.
    private var moveKcal: Int { max(health.todaySummary.activeKcal, todayWorkouts.reduce(0) { $0 + $1.caloriesBurned }) }
    private var exerciseMin: Int { max(health.todaySummary.exerciseMinutes, todayWorkouts.reduce(0) { $0 + $1.durationSeconds / 60 }) }
    private var steps: Int { health.todaySummary.steps }
    private var waterMl: Int { max(health.todaySummary.waterMl, todayWaterMl) }
    private var mindfulMin: Int { max(health.todaySummary.mindfulMinutes, todayMindfulMin) }
    private var sleepHours: Double { max(health.todaySummary.sleepHours, lastNight?.hours ?? 0) }

    private var streak: Int { Insights.currentStreak(activeDays: Insights.activeDays(store.snapshot)) }
    private var workoutsThisWeek: Int { Insights.workoutsThisWeek(store.workouts) }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Hello"
        }
    }

    private var firstName: String {
        profileStore.profile?.displayName.split(separator: " ").first.map(String.init) ?? "there"
    }

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VitalaSpacing.lg) {
                    header
                    if health.isAvailable && !health.isAuthorized && !healthPromptDismissed {
                        connectHealthCard
                    }
                    ringsCard
                    quickLog
                    if !todayWorkouts.isEmpty {
                        todayActivityCard
                    }
                    quickStats
                    streaksRow
                }
                .padding(.horizontal, VitalaSpacing.lg)
                .padding(.bottom, VitalaSpacing.xl)
            }
            .background(VitalaColor.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await health.refreshToday() }
            .task { await health.refreshToday() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task { await health.refreshToday() }
            }
            .sheet(isPresented: $showingWater) {
                WaterTrackerView()
            }
            .sheet(isPresented: $showingMeal) {
                NavigationStack { AddMealView() }
            }
            .sheet(isPresented: $showingSleep) {
                NavigationStack { SleepTrackerView() }
            }
            .sheet(item: $editingWorkout) { session in
                NavigationStack { LogActivityView(editing: session) }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting + ",")
                    .font(VitalaFont.body(15))
                    .foregroundStyle(VitalaColor.textSecondary)
                Text(firstName)
                    .font(VitalaFont.title(28))
                    .foregroundStyle(VitalaColor.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            ProfileButton(size: 48)
        }
        .padding(.top, VitalaSpacing.md)
    }

    private var connectHealthCard: some View {
        HStack(alignment: .top, spacing: VitalaSpacing.sm) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(VitalaColor.coralText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Apple Health")
                    .font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text("See your steps, heart rate and sleep here, and keep what you log in Vitala in your Health record.")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
                HStack(spacing: VitalaSpacing.lg) {
                    Button("Connect") {
                        Task { await health.requestAuthorization() }
                    }
                    .foregroundStyle(VitalaColor.primary)
                    Button("Not now") {
                        withAnimation { healthPromptDismissed = true }
                    }
                    .foregroundStyle(VitalaColor.textSecondary)
                    .accessibilityHint("You can connect later from Profile")
                }
                .font(VitalaFont.bodyMedium(15))
                .buttonStyle(TapTargetButtonStyle())
            }
            Spacer(minLength: 0)
        }
        .vitalaCard()
    }

    // MARK: Rings

    private var ringsCard: some View {
        let moveProg = Double(moveKcal) / Double(max(goals.dailyActiveKcal, 1))
        let exProg = Double(exerciseMin) / Double(max(goals.dailyExerciseMinutes, 1))
        let stepProg = Double(steps) / Double(max(goals.dailySteps, 1))
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: VitalaSpacing.md))
            : AnyLayout(HStackLayout(spacing: VitalaSpacing.md))

        return VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Today's rings",
                          trailing: Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            layout {
                ActivityRings(move: moveProg, exercise: exProg, stand: stepProg)
                    .frame(width: 112, height: 112)
                VStack(alignment: .leading, spacing: 8) {
                    StatPill(label: "Move", value: "\(moveKcal)/\(goals.dailyActiveKcal) kcal", tint: VitalaColor.ringMove)
                    StatPill(label: "Exercise", value: "\(exerciseMin)/\(goals.dailyExerciseMinutes) min", tint: VitalaColor.ringExercise)
                    StatPill(label: "Steps", value: steps.formatted(), tint: VitalaColor.ringStand)
                }
                Spacer(minLength: 0)
            }
        }
        .vitalaCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's rings")
        .accessibilityValue("Move \(moveKcal) of \(goals.dailyActiveKcal) kilocalories. Exercise \(exerciseMin) of \(goals.dailyExerciseMinutes) minutes. Steps \(steps.formatted()) of \(goals.dailySteps.formatted()).")
    }

    // MARK: Quick log

    private var quickLog: some View {
        let mindfulValue = todayMindfulMin == 0 ? "Take a 4-minute pause" : "\(todayMindfulMin) of \(goals.dailyMindfulMinutes) min"
        let sleepValue = lastNight.map { "\(Self.hoursText($0.hours)) last night" } ?? "Log last night"

        return VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Quick log")
            LazyVGrid(columns: columns, spacing: 12) {
                QuickLogButton(icon: "drop.fill", title: "Water",
                               value: "\(units.compactVolume(ml: todayWaterMl)) of \(units.compactVolume(ml: goals.dailyWaterMl))",
                               tint: VitalaColor.water,
                               progress: Double(todayWaterMl) / Double(max(goals.dailyWaterMl, 1)),
                               hint: "Opens the water tracker") {
                    showingWater = true
                }
                QuickLogButton(icon: "fork.knife", title: "Meal",
                               value: "\(todayMealKcal) of \(goals.dailyCalories) kcal",
                               tint: VitalaColor.primary,
                               progress: Double(todayMealKcal) / Double(max(goals.dailyCalories, 1)),
                               hint: "Logs a meal") {
                    showingMeal = true
                }
                QuickLogButton(icon: "leaf.fill", title: "Mindful",
                               value: mindfulValue,
                               tint: VitalaColor.mindful,
                               progress: Double(todayMindfulMin) / Double(max(goals.dailyMindfulMinutes, 1)),
                               hint: "Opens the Mindful tab") {
                    appState.selectedTab = .mindfulness
                }
                QuickLogButton(icon: "moon.stars.fill", title: "Sleep",
                               value: sleepValue,
                               tint: VitalaColor.sleep,
                               progress: (lastNight?.hours ?? 0) / max(goals.sleepHours, 1),
                               hint: "Logs last night's sleep") {
                    showingSleep = true
                }
            }
        }
    }

    // MARK: Today's activity

    private var todayActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Today's activity", trailing: "\(todayWorkouts.count) logged")
            VStack(spacing: 8) {
                ForEach(todayWorkouts) { session in
                    ActivityLogRow(session: session,
                                   onEdit: { editingWorkout = session },
                                   onDelete: { Task { try? await store.deleteWorkout(session) } })
                }
            }
        }
    }

    // MARK: Stats

    private var quickStats: some View {
        let water = units.volumeParts(ml: waterMl)
        return VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "At a glance")
            LazyVGrid(columns: columns, spacing: 12) {
                MetricCard(icon: "drop.fill", label: "Water",
                           value: water.value, unit: water.unit, tint: VitalaColor.water)
                MetricCard(icon: "heart.fill", label: "Latest heart rate",
                           value: health.todaySummary.heartRate.map { "\($0)" } ?? "—",
                           unit: "bpm", tint: VitalaColor.coralText)
                MetricCard(icon: "moon.stars.fill", label: "Sleep",
                           value: sleepHours > 0 ? sleepHours.formatted(.number.precision(.fractionLength(1))) : "—",
                           unit: "hours", tint: VitalaColor.sleep)
                MetricCard(icon: "leaf.fill", label: "Mindful",
                           value: "\(mindfulMin)", unit: "min", tint: VitalaColor.mindful)
            }
        }
    }

    private var streaksRow: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            streakCard(value: "\(streak)", label: "day streak",
                       icon: "flame.fill", tint: VitalaColor.coralText)
            streakCard(value: "\(workoutsThisWeek)/\(goals.weeklyWorkouts)", label: "workouts this week",
                       icon: "figure.run", tint: VitalaColor.primary)
        }
    }

    private func streakCard(value: String, label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(tint.opacity(0.14)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(VitalaFont.title(22))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(label).font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .vitalaCard()
        .accessibilityElement(children: .combine)
    }

    static func hoursText(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int(((hours - Double(h)) * 60).rounded())
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
