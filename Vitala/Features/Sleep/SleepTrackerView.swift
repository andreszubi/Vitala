import SwiftUI

/// Log a new sleep entry, OR edit / delete an existing one when `editing` is set.
/// Present inside a `NavigationStack`.
struct SleepTrackerView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @Environment(\.dismiss) var dismiss

    /// If non-nil, the form is in edit mode for this entry.
    var editing: SleepEntry? = nil

    @State private var bedTime: Date = .now
    @State private var wakeTime: Date = .now
    @State private var quality: SleepEntry.Quality = .good
    @State private var notes: String = ""
    @State private var saving = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    static let maxHours: Double = 16

    private var hours: Double { wakeTime.timeIntervalSince(bedTime) / 3600 }
    private var validationMessage: String? {
        if hours <= 0 { return "Wake time needs to be after bedtime." }
        if hours > Self.maxHours { return "That's over \(Int(Self.maxHours)) hours — check the dates." }
        if wakeTime > .now.addingTimeInterval(60) { return "Wake time can't be in the future." }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                timesCard
                qualityCard
                notesCard

                if editing != nil {
                    SecondaryButton(title: "Delete this entry", icon: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, VitalaSpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(VitalaColor.background.ignoresSafeArea())
        .navigationTitle(editing == nil ? "Log sleep" : "Edit sleep")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await save() } }
                    .disabled(validationMessage != nil || saving)
            }
        }
        .confirmationDialog("Delete this sleep entry?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .keyboardDoneButton()
        .onAppear(perform: load)
    }

    // MARK: Sections

    private var timesCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: editing == nil ? "Last night" : "Times")

            DatePicker("Bedtime", selection: $bedTime, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Wake time", selection: $wakeTime, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])

            Divider().overlay(VitalaColor.hairline)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle")
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.danger)
            } else {
                HStack {
                    Spacer()
                    Text(DashboardView.hoursText(hours))
                        .font(VitalaFont.title(28))
                        .foregroundStyle(VitalaColor.primary)
                        .accessibilityLabel("Duration, \(DashboardView.hoursText(hours))")
                    Spacer()
                }
            }
        }
        .font(VitalaFont.body(16))
        .tint(VitalaColor.primary)
        .vitalaCard()
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "How did it feel?")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                ForEach(SleepEntry.Quality.allCases) { q in
                    QualityChip(quality: q, isSelected: quality == q) {
                        quality = q
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            SectionHeader(title: "Notes")
            TextField("Notes", text: $notes, prompt: Text("Anything notable about last night?"), axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .surfaceCard()
        }
    }

    // MARK: Actions

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let e = editing {
            bedTime = e.bedTime
            wakeTime = e.wakeTime
            quality = e.quality
            notes = e.notes ?? ""
        } else {
            // Default to a typical night that ended this morning.
            let cal = Calendar.current
            let sevenAM = cal.date(bySettingHour: 7, minute: 0, second: 0, of: .now) ?? .now
            wakeTime = min(sevenAM, .now)
            let goal = profileStore.profile?.goals.sleepHours ?? 8
            bedTime = wakeTime.addingTimeInterval(-goal * 3600)
        }
    }

    private func save() async {
        guard validationMessage == nil else { return }
        saving = true; defer { saving = false }
        let entry = SleepEntry(
            id: editing?.id ?? UUID().uuidString,
            bedTime: bedTime,
            wakeTime: wakeTime,
            quality: quality,
            notes: notes.isEmpty ? nil : notes
        )
        try? await DataStore.shared.logSleep(entry)
        Haptics.success()
        dismiss()
    }

    private func delete() async {
        guard let e = editing else { return }
        try? await DataStore.shared.deleteSleep(e)
        dismiss()
    }
}

private struct QualityChip: View {
    let quality: SleepEntry.Quality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: quality.icon)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(quality.label)
                    .font(VitalaFont.caption(12))
            }
            .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .fill(isSelected ? VitalaColor.primary.opacity(0.1) : VitalaColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous)
                    .stroke(isSelected ? VitalaColor.primary : VitalaColor.hairline,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(quality.label) sleep")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
