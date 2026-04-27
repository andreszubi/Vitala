import SwiftUI

/// One row in a list of logged WorkoutSessions.
/// Tap → edit. Long-press → context menu with Edit / Delete.
/// Trailing trash icon also exposes Delete inline (more discoverable than the menu).
struct ActivityLogRow: View {
    let session: WorkoutSession
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(VitalaColor.primary.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "figure.run")
                    .foregroundStyle(VitalaColor.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(VitalaColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
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

    private var subtitle: String {
        let mins = max(1, session.durationSeconds / 60)
        return "\(session.startedAt.formatted(date: .omitted, time: .shortened)) · \(mins) min · \(session.caloriesBurned) kcal"
    }
}
