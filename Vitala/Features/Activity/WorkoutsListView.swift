import SwiftUI

struct WorkoutsListView: View {
    @State private var category: Workout.Category? = nil
    @State private var showingLogActivity = false
    @State private var editingSession: WorkoutSession? = nil
    @State private var selectedDate: Date = .now
    @Environment(\.dynamicTypeSize) private var typeSize

    @ObservedObject private var store = DataStore.shared

    private var workouts: [Workout] {
        guard let category else { return WorkoutLibrary.all }
        return WorkoutLibrary.all.filter { $0.category == category }
    }

    private var sessionsOnSelectedDate: [WorkoutSession] {
        store.workouts
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var columns: [GridItem] {
        typeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(
                    title: "Activity",
                    subtitle: "Pick a session — or log your own.",
                    trailing: AnyView(
                        HeaderActionButton(title: "Log", accessibilityLabel: "Log an activity") {
                            showingLogActivity = true
                        }
                    )
                )
                .padding(.top, VitalaSpacing.md)

                DateNavigator(date: $selectedDate)

                sessionsForDateSection

                VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
                    SectionHeader(title: "Library", trailing: "\(workouts.count) sessions")
                    categoryFilter
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(workouts) { w in
                            NavigationLink(destination: WorkoutDetailView(workout: w)) {
                                WorkoutCard(workout: w)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    if workouts.isEmpty {
                        EmptyStateRow(text: "No sessions in this category yet.", icon: "sparkles")
                    }
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingLogActivity) {
            NavigationStack { LogActivityView(forDate: selectedDate) }
        }
        .sheet(item: $editingSession) { session in
            NavigationStack { LogActivityView(editing: session) }
        }
    }

    private var sessionsForDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Sessions",
                          trailing: sessionsOnSelectedDate.isEmpty ? nil : "\(sessionsOnSelectedDate.count) logged")

            if sessionsOnSelectedDate.isEmpty {
                EmptyStateRow(text: "No activities logged on this day.",
                              icon: "figure.run.circle")
            } else {
                VStack(spacing: 8) {
                    ForEach(sessionsOnSelectedDate) { s in
                        ActivityLogRow(
                            session: s,
                            onEdit: { editingSession = s },
                            onDelete: { Task { try? await store.deleteWorkout(s) } }
                        )
                    }
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isOn: category == nil) { category = nil }
                ForEach(Workout.Category.allCases) { c in
                    FilterChip(label: c.label, icon: c.icon, isOn: category == c) { category = c }
                }
            }
            .glassGroup()
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by type")
    }
}

/// Capsule filter used above libraries. Native glass on iOS 26+.
struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isOn: Bool
    let action: () -> Void

    private var content: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.caption.weight(.semibold)).accessibilityHidden(true)
            }
            Text(label).font(VitalaFont.caption(13))
        }
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    content
                        .foregroundStyle(isOn ? .white : VitalaColor.textPrimary)
                        .frame(minHeight: 28)
                }
                .buttonBorderShape(.capsule)
                .glassButtonStyle(prominent: isOn, tint: isOn ? VitalaColor.primaryFill : nil)
            } else {
                Button(action: action) {
                    content
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(isOn ? AnyShapeStyle(VitalaColor.primaryGradient) : AnyShapeStyle(VitalaColor.surface)))
                        .overlay(Capsule().stroke(isOn ? .clear : VitalaColor.hairline, lineWidth: 1))
                        .foregroundStyle(isOn ? .white : VitalaColor.textPrimary)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 44)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: workout.coverTint),
                                                  Color(hex: workout.coverTint).opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: workout.imageSystemName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .frame(height: 110)
            .accessibilityHidden(true)

            Text(workout.name)
                .font(VitalaFont.bodyMedium(15))
                .foregroundStyle(VitalaColor.textPrimary)
                .lineLimit(2, reservesSpace: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    duration
                    Spacer(minLength: 4)
                    difficulty
                }
                VStack(alignment: .leading, spacing: 6) {
                    duration
                    difficulty
                }
            }
            .foregroundStyle(VitalaColor.textSecondary)
        }
        .padding(10)
        .surfaceCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(workout.name)
        .accessibilityValue("\(workout.category.label), \(workout.durationMinutes) minutes, \(workout.difficulty.label)")
    }

    private var duration: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock").font(.caption2).accessibilityHidden(true)
            Text("\(workout.durationMinutes) min")
                .font(VitalaFont.caption(12))
                .fixedSize()
        }
    }

    private var difficulty: some View {
        Text(workout.difficulty.label)
            .font(VitalaFont.caption(11))
            .fixedSize()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(VitalaColor.primary.opacity(0.12)))
            .foregroundStyle(VitalaColor.primary)
    }
}
