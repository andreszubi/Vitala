import SwiftUI

struct MindfulnessView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @ObservedObject private var store = DataStore.shared

    @State private var category: MindfulnessSession.Category? = nil
    @State private var historyDate: Date = .now
    @State private var editingEntry: LoggedMindfulness? = nil
    @State private var playing: MindfulnessSession? = nil

    private var sessions: [MindfulnessSession] {
        guard let category else { return MindfulnessLibrary.all }
        return MindfulnessLibrary.all.filter { $0.category == category }
    }

    private var entriesOnSelectedDay: [LoggedMindfulness] {
        store.mindfulness
            .filter { Calendar.current.isDate($0.completedAt, inSameDayAs: historyDate) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private var totalMinutesOnSelectedDay: Int {
        entriesOnSelectedDay.reduce(0) { $0 + $1.minutes }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(title: "Mindfulness", subtitle: "A pause is productive.")
                    .padding(.top, VitalaSpacing.md)

                quickBreathCard
                historySection
                browseLibrarySection
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingEntry) { entry in
            NavigationStack { EditMindfulnessSheet(entry: entry) }
        }
        .fullScreenCover(item: $playing) { session in
            SessionPlayerView(session: session)
        }
    }

    // MARK: Quick start

    private var quickBreathCard: some View {
        let session = MindfulnessLibrary.quickReset
        return Button {
            playing = session
        } label: {
            HStack(spacing: VitalaSpacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1-minute reset")
                        .font(VitalaFont.caption(12))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.22)))
                    Text("Quick reset")
                        .font(VitalaFont.title(22))
                    Text("Breathe in, hold, breathe out, hold — four seconds each.")
                        .font(VitalaFont.body(14))
                }
                .foregroundStyle(.white)
                Spacer(minLength: 0)
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .padding(VitalaSpacing.md)
            .background(RoundedRectangle(cornerRadius: VitalaRadius.lg, style: .continuous)
                .fill(VitalaColor.primaryGradient))
            .shadow(color: VitalaColor.primaryFill.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Start a one-minute reset")
        .accessibilityHint("Guided box breathing")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: History

    private var historySection: some View {
        let goal = profileStore.profile?.goals.dailyMindfulMinutes ?? 10
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History",
                          trailing: totalMinutesOnSelectedDay > 0 ? "\(totalMinutesOnSelectedDay) of \(goal) min" : nil)

            DateNavigator(date: $historyDate)

            if entriesOnSelectedDay.isEmpty {
                EmptyStateRow(text: "No mindful sessions on this day.", icon: "leaf")
            } else {
                VStack(spacing: 8) {
                    ForEach(entriesOnSelectedDay) { entry in
                        LogRow(icon: "leaf.fill",
                               tint: VitalaColor.mindful,
                               title: entry.title,
                               subtitle: "\(entry.completedAt.formatted(date: .omitted, time: .shortened)) · \(entry.minutes) min",
                               noun: "session",
                               onEdit: { editingEntry = entry },
                               onDelete: { Task { try? await store.deleteMindfulness(entry) } })
                    }
                }
            }
        }
    }

    // MARK: Library

    private var browseLibrarySection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Browse", trailing: "\(sessions.count) sessions")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isOn: category == nil) { category = nil }
                    ForEach(MindfulnessSession.Category.allCases) { c in
                        FilterChip(label: c.label, isOn: category == c) { category = c }
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Filter by type")

            VStack(spacing: 10) {
                ForEach(sessions) { s in
                    Button { playing = s } label: {
                        SessionRow(session: s)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint("Starts the session")
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: MindfulnessSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: session.tint)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(session.subtitle).font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer(minLength: 4)
            Text("\(session.minutes) min").font(VitalaFont.caption(13))
                .foregroundStyle(VitalaColor.textSecondary)
            Image(systemName: "play.fill").font(.footnote)
                .foregroundStyle(VitalaColor.primary)
                .accessibilityHidden(true)
        }
        .padding(12)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
