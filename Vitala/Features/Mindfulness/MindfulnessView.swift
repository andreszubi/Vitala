import SwiftUI

struct MindfulnessView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @ObservedObject private var store = DataStore.shared

    @State private var category: MindfulnessSession.Category? = nil
    @State private var historyDate: Date = .now
    @State private var editingEntry: LoggedMindfulness? = nil
    @State private var playing: MindfulnessSession? = nil
    @State private var journalDate: Date = .now
    @State private var journalSheet: JournalSheet? = nil
    /// A session to write about once the player has closed.
    @State private var pendingJournal: LoggedMindfulness? = nil

    private enum JournalSheet: Identifiable {
        case new(after: LoggedMindfulness?, on: Date)
        case edit(JournalEntry)
        var id: String {
            switch self {
            case .new(let session, _): "new-\(session?.id ?? "")"
            case .edit(let entry): entry.id
            }
        }
    }

    private var journalOnSelectedDay: [JournalEntry] {
        store.journal
            .filter { Calendar.current.isDate($0.date, inSameDayAs: journalDate) }
            .sorted { $0.date > $1.date }
    }

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
                ScreenHeader(
                    title: "Mindfulness",
                    subtitle: "A pause is productive.",
                    trailing: AnyView(
                        GlassIconButton(systemName: "square.and.pencil", label: "New journal entry",
                                        foreground: VitalaColor.primary) {
                            journalSheet = .new(after: nil, on: journalDate)
                        }
                    )
                )
                .padding(.top, VitalaSpacing.md)

                quickBreathCard
                historySection
                journalSection
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
        .fullScreenCover(item: $playing, onDismiss: {
            if let session = pendingJournal {
                pendingJournal = nil
                journalSheet = .new(after: session, on: .now)
            }
        }) { session in
            SessionPlayerView(session: session) { saved in pendingJournal = saved }
        }
        .sheet(item: $journalSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .new(let session, let day): JournalEntrySheet(after: session, on: day)
                case .edit(let entry): JournalEntrySheet(editing: entry)
                }
            }
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

    // MARK: Journal

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Journal",
                          trailing: journalOnSelectedDay.isEmpty ? nil : "\(journalOnSelectedDay.count) \(journalOnSelectedDay.count == 1 ? "entry" : "entries")")

            DateNavigator(date: $journalDate)

            if journalOnSelectedDay.isEmpty {
                Button {
                    journalSheet = .new(after: nil, on: journalDate)
                } label: {
                    EmptyStateRow(text: "No entries on this day. Tap to write one.", icon: "book.closed")
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("No entries on this day")
                .accessibilityHint("Writes a new journal entry")
            } else {
                VStack(spacing: 8) {
                    ForEach(journalOnSelectedDay) { entry in
                        LogRow(icon: entry.mood.icon,
                               tint: VitalaColor.mindful,
                               title: entry.mood.label,
                               subtitle: journalSubtitle(entry),
                               noun: "journal entry",
                               onEdit: { journalSheet = .edit(entry) },
                               onDelete: { deleteJournal(entry) })
                    }
                }
            }
        }
    }

    private func journalSubtitle(_ entry: JournalEntry) -> String {
        var parts = [entry.date.formatted(date: .omitted, time: .shortened)]
        if let title = entry.sessionTitle { parts.append("After \(title)") }
        parts.append(entry.preview)
        return parts.joined(separator: " · ")
    }

    private func deleteJournal(_ entry: JournalEntry) {
        Task { try? await store.deleteJournal(entry) }
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
                .glassGroup()
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
