import SwiftUI

/// Day-by-day navigator — chevron back, label (Today / Yesterday / Apr 25, 2026),
/// chevron forward (disabled on today). Tap the label to open a calendar sheet.
struct DateNavigator: View {
    @Binding var date: Date
    @State private var showPicker = false

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: previousDay) {
                chevron("chevron.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")

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
                .padding(.horizontal, 14)
                .surfaceCard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Showing \(label)")
            .accessibilityHint("Opens a calendar to choose another day")

            Button(action: nextDay) {
                chevron("chevron.right")
                    .opacity(isToday ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isToday)
            .accessibilityLabel("Next day")
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
    }

    private var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name)
            .font(.subheadline.weight(.semibold))
            .frame(width: 44, height: 44)
            .background(Circle().fill(VitalaColor.surface))
            .overlay(Circle().stroke(VitalaColor.hairline, lineWidth: 1))
            .foregroundStyle(VitalaColor.textPrimary)
            .contentShape(Circle())
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
