import SwiftUI

struct MindfulnessView: View {
    @ObservedObject private var store = FirestoreService.shared

    @State private var category: MindfulnessSession.Category? = nil
    @State private var historyDate: Date = .now
    @State private var editingEntry: LoggedMindfulness? = nil

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

                // History promoted to the top — easier to see and edit your sessions.
                historySection

                browseLibrarySection
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.xl)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .sheet(item: $editingEntry) { entry in
            EditMindfulnessSheet(entry: entry)
        }
    }

    private var browseLibrarySection: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            HStack {
                Text("Browse").font(VitalaFont.headline(18))
                Spacer()
                Text("\(MindfulnessLibrary.all.count) sessions")
                    .font(VitalaFont.caption()).foregroundStyle(VitalaColor.textSecondary)
            }
            .padding(.top, VitalaSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", isOn: category == nil) { category = nil }
                    ForEach(MindfulnessSession.Category.allCases) { c in
                        chip(c.label, isOn: category == c) { category = c }
                    }
                }
            }

            VStack(spacing: 10) {
                ForEach(sessions) { s in
                    NavigationLink {
                        SessionPlayerView(session: s)
                    } label: {
                        SessionRow(session: s)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text("History").font(VitalaFont.headline(18))
                Spacer()
                if totalMinutesOnSelectedDay > 0 {
                    Text("\(totalMinutesOnSelectedDay) min")
                        .font(VitalaFont.caption())
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }
            .padding(.top, VitalaSpacing.sm)

            DateNavigator(date: $historyDate)

            if entriesOnSelectedDay.isEmpty {
                EmptyStateRow(text: "No mindful sessions on this day.",
                              icon: "leaf.fill")
            } else {
                VStack(spacing: 8) {
                    ForEach(entriesOnSelectedDay) { entry in
                        MindfulLogRow(
                            entry: entry,
                            onEdit: { editingEntry = entry },
                            onDelete: {
                                Task { try? await store.deleteMindfulness(entry) }
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: Existing UI

    private var quickBreathCard: some View {
        NavigationLink {
            SessionPlayerView(session: MindfulnessLibrary.all[0])
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1-minute reset")
                        .font(VitalaFont.caption(12))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.white.opacity(0.25))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    Text("Box breathing")
                        .font(VitalaFont.title(22)).foregroundStyle(.white)
                    Text("4-second inhale, hold, exhale, hold.")
                        .font(VitalaFont.body(13)).foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50)).foregroundStyle(.white)
            }
            .padding(VitalaSpacing.md)
            .background(VitalaColor.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.lg))
            .shadow(color: VitalaColor.primary.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func chip(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(VitalaFont.caption(13))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(isOn ? VitalaColor.primary : VitalaColor.surface)
                .foregroundStyle(isOn ? .white : VitalaColor.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SessionRow: View {
    let session: MindfulnessSession
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color(hex: session.tint).opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: session.icon).foregroundStyle(Color(hex: session.tint))
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title).font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(session.subtitle).font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            Spacer()
            Text("\(session.minutes) min").font(VitalaFont.caption(13))
                .foregroundStyle(VitalaColor.textSecondary)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VitalaColor.muted)
        }
        .padding(12)
        .background(VitalaColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
    }
}

/// Row used in the History section for logged mindful sessions.
struct MindfulLogRow: View {
    let entry: LoggedMindfulness
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(VitalaColor.sage.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: "leaf.fill").foregroundStyle(VitalaColor.sage)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .lineLimit(1)
                Text("\(entry.completedAt.formatted(date: .omitted, time: .shortened)) · \(entry.minutes) min")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
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
