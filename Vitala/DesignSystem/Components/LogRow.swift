import SwiftUI

/// A logged entry with Edit and Delete. The whole row is a button that edits;
/// a trailing menu (and VoiceOver custom actions) offer Edit and Delete.
/// Delete always asks for confirmation.
struct EditableRow<Content: View>: View {
    /// What the entry is, for VoiceOver and the confirmation title ("water entry").
    let noun: String
    var onEdit: (() -> Void)? = nil
    /// Nil for read-only entries, such as ones from Apple Health.
    var onDelete: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    @State private var confirmingDelete = false

    var body: some View {
        HStack(spacing: 4) {
            Group {
                if let onEdit {
                    Button(action: onEdit) { rowContent }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edits this \(noun)")
                } else {
                    rowContent.accessibilityElement(children: .combine)
                }
            }
            .accessibilityActions {
                if onDelete != nil {
                    Button("Delete") { confirmingDelete = true }
                }
            }

            if onEdit != nil || onDelete != nil { menu }
        }
        .padding(.leading, 10)
        .padding(.vertical, 6)
        .padding(.trailing, 2)
        .surfaceCard()
        .contextMenu {
            if let onEdit {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            }
            if onDelete != nil {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog("Delete this \(noun)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var menu: some View {
        Menu {
            if let onEdit {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            }
            if onDelete != nil {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(VitalaColor.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More options")
    }

    private var rowContent: some View {
        content()
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// The common icon + title + subtitle layout for logged entries.
struct LogRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let noun: String
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        EditableRow(noun: noun, onEdit: onEdit, onDelete: onDelete) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.14)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitalaFont.bodyMedium(15))
                        .foregroundStyle(VitalaColor.textPrimary)
                    Text(subtitle)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// One row in a list of logged WorkoutSessions.
struct ActivityLogRow: View {
    let session: WorkoutSession
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LogRow(icon: session.category?.icon ?? "figure.run",
               tint: VitalaColor.primary,
               title: session.workoutName,
               subtitle: subtitle,
               noun: "activity",
               onEdit: onEdit,
               onDelete: onDelete)
    }

    private var subtitle: String {
        let mins = max(1, session.durationSeconds / 60)
        var parts = [session.startedAt.formatted(date: .omitted, time: .shortened),
                     "\(mins) min",
                     "\(session.caloriesBurned) kcal"]
        if let km = session.distanceKm, km > 0 {
            parts.append(Measurement(value: km, unit: UnitLength.kilometers)
                .formatted(.measurement(width: .abbreviated, usage: .road)))
        }
        return parts.joined(separator: " · ")
    }
}

struct EmptyStateRow: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(VitalaColor.muted)
                .frame(width: 40, height: 40)
                .background(Circle().fill(VitalaColor.muted.opacity(0.12)))
                .accessibilityHidden(true)
            Text(text)
                .font(VitalaFont.body(14))
                .foregroundStyle(VitalaColor.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
