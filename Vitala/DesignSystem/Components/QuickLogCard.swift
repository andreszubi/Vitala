import SwiftUI

/// A tile for the dashboard's quick-log grid.
/// Vertical layout so the title and value get the full card width.
struct QuickLogCard: View {
    let icon: String
    let title: String
    let value: String?
    let tint: Color
    /// Optional 0...1 progress that renders a thin bar at the bottom.
    var progress: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.15)))
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(tint.opacity(0.12)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let value, !value.isEmpty {
                    Text(value)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(tint.opacity(0.15))
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .surfaceCard()
    }
}

// MARK: - Button wrapper

struct QuickLogButton: View {
    let icon: String
    let title: String
    let value: String?
    let tint: Color
    var progress: Double? = nil
    var hint: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickLogCard(icon: icon, title: title, value: value, tint: tint, progress: progress)
        }
        .accessibilityIdentifier("quicklog.\(title.lowercased())")
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(.isButton)
    }
}
