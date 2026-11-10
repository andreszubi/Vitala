import SwiftUI

/// Day-by-day navigator — chevron back, label (Today / Yesterday / Apr 25, 2026),
/// chevron forward (disabled on today). Tap the label to open a calendar sheet.
struct DateNavigator: View {
    @Binding var date: Date
    @State private var showPicker = false
    @Environment(\.scenePhase) private var scenePhase
    /// The day that counted as today when this last looked.
    @State private var today = Calendar.current.startOfDay(for: .now)

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        HStack(spacing: 8) {
            GlassIconButton(systemName: "chevron.left", label: "Previous day", action: previousDay)

            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(VitalaColor.primary)
                        .accessibilityHidden(true)
                    Text(label)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.textPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonBorderShape(.capsule)
            .glassButtonStyle()
            .accessibilityLabel("Showing \(label)")
            .accessibilityHint("Opens a calendar to choose another day")

            GlassIconButton(systemName: "chevron.right", label: "Next day", action: nextDay)
                .disabled(isToday)
                .opacity(isToday ? 0.35 : 1)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Day",
                           selection: $date,
                           in: ...Date.now,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(VitalaColor.primary)
                    .padding()
                    .navigationTitle("Pick a day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showPicker = false }
                        }
                        if !isToday {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Today") { date = .now; showPicker = false }
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        // A screen left open overnight would otherwise keep showing, and
        // logging to, what has become yesterday.
        .onAppear(perform: followToday)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { followToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)) { _ in followToday() }
    }

    private func followToday() {
        let now = Date.now
        date = DayFollowing.selection(date, lastToday: today, now: now)
        today = Calendar.current.startOfDay(for: now)
    }

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func previousDay() {
        guard let new = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return }
        date = new
    }

    private func nextDay() {
        guard !isToday else { return }
        guard let new = Calendar.current.date(byAdding: .day, value: 1, to: date) else { return }
        // Don't go past today
        date = min(new, .now)
    }
}

/// Keeps a day picker on today across midnight.
enum DayFollowing {
    /// The day to show now. A selection that was "today" when last checked
    /// moves on to the new today; a day the user chose on purpose stays.
    static func selection(_ selected: Date, lastToday: Date, now: Date, calendar: Calendar = .current) -> Date {
        guard !calendar.isDate(lastToday, inSameDayAs: now),
              calendar.isDate(selected, inSameDayAs: lastToday) else { return selected }
        return now
    }
}
