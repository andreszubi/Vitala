import SwiftUI

struct MetricCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    var tint: Color = VitalaColor.primary
    var trend: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: VitalaSpacing.xs) {
            HStack {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundStyle(tint)
                }
                Spacer()
                if let trend {
                    Text(trend)
                        .font(VitalaFont.caption(11))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(VitalaColor.success.opacity(0.15))
                        .foregroundStyle(VitalaColor.success)
                        .clipShape(Capsule())
                }
            }
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(VitalaFont.title(26))
                    .foregroundStyle(VitalaColor.textPrimary)
                Text(unit)
                    .font(VitalaFont.caption(13))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard()
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(VitalaColor.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1))
    }
}
