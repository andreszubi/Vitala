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
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(tint.opacity(0.14)))
                Spacer()
                if let trend {
                    Text(trend)
                        .font(VitalaFont.caption(11))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(VitalaColor.success.opacity(0.14))
                        .foregroundStyle(VitalaColor.success)
                        .clipShape(Capsule())
                }
            }
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    valueText
                    unitText
                }
                VStack(alignment: .leading, spacing: 0) {
                    valueText
                    unitText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vitalaCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue([value, unit, trend].compactMap { $0 }.joined(separator: " "))
    }

    private var valueText: some View {
        Text(value)
            .font(VitalaFont.title(26))
            .foregroundStyle(VitalaColor.textPrimary)
            .lineLimit(1)
    }

    private var unitText: some View {
        Text(unit)
            .font(VitalaFont.caption(13))
            .foregroundStyle(VitalaColor.textSecondary)
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let tint: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(label)
                .font(VitalaFont.caption())
                .foregroundStyle(VitalaColor.textSecondary)
            Text(value)
                .font(VitalaFont.bodyMedium(14))
                .foregroundStyle(VitalaColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Capsule().fill(VitalaColor.background))
        .overlay(Capsule().stroke(VitalaColor.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
