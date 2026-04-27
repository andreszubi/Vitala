import SwiftUI
import Charts

/// Log a new sleep entry, OR edit / delete an existing one when `editing` is set.
struct SleepTrackerView: View {
    @ObservedObject private var store = FirestoreService.shared
    @Environment(\.dismiss) var dismiss

    /// If non-nil, the form is in edit mode for this entry.
    var editing: SleepEntry? = nil

    @State private var bedTime: Date = defaultBed()
    @State private var wakeTime: Date = .now
    @State private var quality: SleepEntry.Quality = .good
    @State private var notes: String = ""
    @State private var saving = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false

    private static func defaultBed() -> Date {
        Calendar.current.date(bySettingHour: 23, minute: 0, second: 0,
                              of: .now.addingTimeInterval(-86_400)) ?? .now
    }

    private var hours: Double {
        max(0, wakeTime.timeIntervalSince(bedTime) / 3600)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VitalaSpacing.lg) {
                ScreenHeader(title: editing == nil ? "Log sleep" : "Edit sleep",
                             subtitle: "Rested rises to most things.")
                    .padding(.top, VitalaSpacing.md)

                lastNightCard
                qualityCard

                if let n = notesBinding {
                    notesCard(notes: n)
                }

                if editing != nil {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete this entry").font(VitalaFont.bodyMedium(15))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VitalaColor.coral.opacity(0.12))
                        .foregroundStyle(VitalaColor.coral)
                        .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.bottom, VitalaSpacing.lg)
        }
        .background(VitalaColor.background.ignoresSafeArea())
        .toolbar(.hidden)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: saveButtonTitle,
                          icon: "moon.stars.fill",
                          isLoading: saving) {
                Task { await save() }
            }
            .padding(.horizontal, VitalaSpacing.lg)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .confirmationDialog("Delete this sleep entry?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await delete() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let e = editing {
                bedTime = e.bedTime
                wakeTime = e.wakeTime
                quality = e.quality
                notes = e.notes ?? ""
            }
        }
    }

    private var saveButtonTitle: String {
        if saving { return "Saving…" }
        return editing == nil ? "Save sleep" : "Save changes"
    }

    private var notesBinding: Binding<String>? { $notes }

    // MARK: Sections

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            Text(editing == nil ? "Last night" : "Times").font(VitalaFont.headline(18))

            VStack(alignment: .leading, spacing: 12) {
                SleepTimeRow(label: "Bedtime", date: $bedTime)
                SleepTimeRow(label: "Wake time", date: $wakeTime)
            }

            HStack {
                Spacer()
                Text(String(format: "%.1f hours", hours))
                    .font(VitalaFont.title(28))
                    .foregroundStyle(VitalaColor.primary)
                Spacer()
            }
            .padding(.top, 4)
        }
        .vitalaCard()
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            Text("How did it feel?").font(VitalaFont.headline(18))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                     count: 4),
                      spacing: 8) {
                ForEach(SleepEntry.Quality.allCases) { q in
                    QualityChip(quality: q, isSelected: quality == q) {
                        quality = q
                    }
                }
            }
        }
    }

    private func notesCard(notes: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.sm) {
            Text("Notes").font(VitalaFont.headline(18))
            TextField("Anything notable about last night?", text: notes, axis: .vertical)
                .lineLimit(3...5)
                .padding(12)
                .background(VitalaColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: VitalaRadius.md)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    // MARK: Actions

    private func save() async {
        saving = true; defer { saving = false }
        let entry = SleepEntry(
            id: editing?.id ?? UUID().uuidString,
            bedTime: bedTime,
            wakeTime: wakeTime,
            quality: quality,
            notes: notes.isEmpty ? nil : notes
        )
        try? await FirestoreService.shared.logSleep(entry)
        dismiss()
    }

    private func delete() async {
        guard let e = editing else { return }
        try? await FirestoreService.shared.deleteSleep(e)
        dismiss()
    }
}

// MARK: - Subviews

private struct SleepTimeRow: View {
    let label: String
    @Binding var date: Date

    var body: some View {
        HStack {
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
                .frame(width: 80, alignment: .leading)
            Spacer(minLength: 4)
            DatePicker("", selection: $date,
                       displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
        }
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
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.muted)
                Text(quality.label)
                    .font(VitalaFont.caption(11))
                    .foregroundStyle(isSelected ? VitalaColor.primary : VitalaColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? VitalaColor.primary.opacity(0.1) : VitalaColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: VitalaRadius.md)
                    .stroke(isSelected ? VitalaColor.primary : Color.black.opacity(0.05),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
