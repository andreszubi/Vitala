import SwiftUI

struct WorkoutsListView: View {
    @State private var category: Workout.Category? = nil
    @State private var showingLogActivity = false
    @State private var editingSession: WorkoutSession? = nil
    @State private var selectedDate: Date = .now

    @ObservedObject private var store = FirestoreService.shared

    private var workouts: [Workout] {
        guard let category else { return WorkoutLibrary.all }
        return WorkoutLibrary.all.filter { $0.category == category }
    }

    private var sessionsOnSelectedDate: [WorkoutSession] {
        store.workouts
            .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDate) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(
                    title: "Activity",
                    subtitle: "Pick a session — or log your own.",
                    trailing: AnyView(
                        Button {
                            showingLogActivity = true
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

                DateNavigator(date: $selectedDate)

                sessionsForDateSection

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(label: "All", isOn: category == nil) { category = nil }
                        ForEach(Workout.Category.allCases) { c in
                            chip(label: c.label, icon: c.icon, isOn: category == c) { category = c }
                        }
                    }
                    .padding(.horizontal, 2)
                }

                SectionHeader(title: "Library")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(workouts) { w in
                        NavigationLink(destination: WorkoutDetailView(workout: w)) {
                            WorkoutCard(workout: w)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .sheet(isPresented: $showingLogActivity) {
            LogActivityView(forDate: selectedDate)
        }
        .sheet(item: $editingSession) { session in
            LogActivityView(editing: session)
        }
    }

    private var sessionsForDateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sessions").font(VitalaFont.headline(18))
                Spacer()
                if !sessionsOnSelectedDate.isEmpty {
                    Text("\(sessionsOnSelectedDate.count) logged")
                        .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
                }
            }

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

    private func chip(label: String, icon: String? = nil, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .semibold)) }
                Text(label).font(VitalaFont.caption(13))
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(isOn ? VitalaColor.primary : VitalaColor.surface)
            .foregroundStyle(isOn ? .white : VitalaColor.textPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [Color(hex: workout.coverTint),
                                                  Color(hex: workout.coverTint).opacity(0.7)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: workout.imageSystemName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(height: 110)

            Text(workout.name).font(VitalaFont.bodyMedium(15))
                .foregroundStyle(VitalaColor.textPrimary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.system(size: 11))
                Text("\(workout.durationMinutes) min")
                    .font(VitalaFont.caption(12))
                Spacer()
                Text(workout.difficulty.label.capitalized)
                    .font(VitalaFont.caption(11))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(VitalaColor.primary.opacity(0.12))
                    .foregroundStyle(VitalaColor.primary)
                    .clipShape(Capsule())
            }
            .foregroundStyle(VitalaColor.textSecondary)
        }
        .padding(10)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
    }
}

struct EmptyStateRow: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(VitalaColor.muted)
                .frame(width: 40, height: 40)
                .background(VitalaColor.muted.opacity(0.12))
                .clipShape(Circle())
            Text(text)
                .font(VitalaFont.body(14))
                .foregroundStyle(VitalaColor.textSecondary)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
    }
}

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self = Color(red: r, green: g, blue: b)
    }
}
