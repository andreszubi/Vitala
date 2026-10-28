import SwiftUI

/// Reusable list-row content used across Settings, Profile, Mindfulness, etc.
/// Display-only: wrap it in a `Button` or `NavigationLink` to make it tappable,
/// so VoiceOver announces it as a control.
struct RowItem: View {
    let icon: String
    let iconTint: Color
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: VitalaSpacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(iconTint.opacity(0.14)))
                .accessibilityHidden(true)
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
            Spacer(minLength: VitalaSpacing.xs)
            if let trailing {
                Text(trailing)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VitalaColor.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .frame(minHeight: 44)
        .surfaceCard()
        .contentShape(Rectangle())
    }
}
