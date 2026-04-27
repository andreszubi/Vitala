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

            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitalaColor.primary)
                    Text(label)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(VitalaColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: VitalaRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: VitalaRadius.md)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button(action: nextDay) {
                chevron("chevron.right")
                    .opacity(isToday ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isToday)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("",
                           selection: $date,
                           in: ...Date.now,
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Pick a day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showPicker = false }
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
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func chevron(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .frame(width: 40, height: 40)
            .background(VitalaColor.surface)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
            .foregroundStyle(VitalaColor.textPrimary)
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
