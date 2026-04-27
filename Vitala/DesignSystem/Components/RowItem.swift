import SwiftUI

/// Reusable list-row used across Workouts, Mindfulness, Settings, etc.
struct RowItem: View {
    let icon: String
    let iconTint: Color
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: VitalaSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconTint.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon).foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VitalaFont.bodyMedium(16))
                    .foregroundStyle(VitalaColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(VitalaFont.caption(13))
                        .foregroundStyle(VitalaColor.textSecondary)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitalaColor.muted.opacity(0.7))
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .glassCard(in: RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
    }
}
