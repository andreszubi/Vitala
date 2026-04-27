import SwiftUI

/// A polished tile for the dashboard's quick-log row.
/// Vertical layout so the title and value get the FULL card width.
struct QuickLogCard: View {
    let icon: String
    let title: String
    let value: String?
    let tint: Color
    /// Optional 0...1 progress that renders a thin bar at the bottom.
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(tint.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VitalaFont.bodyMedium(15))
                    .foregroundStyle(VitalaColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let value, !value.isEmpty {
                    Text(value)
                        .font(VitalaFont.caption(12))
                        .foregroundStyle(VitalaColor.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tint.opacity(0.15))
                            .frame(height: 4)
                        Capsule()
                            .fill(tint)
                            .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)),
                                   height: 4)
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(in: RoundedRectangle(cornerRadius: VitalaRadius.md, style: .continuous))
    }
}

// MARK: - Convenience wrappers (Button vs NavigationLink)

struct QuickLogButton: View {
    let icon: String
    let title: String
    let value: String?
    let tint: Color
    var progress: Double? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            QuickLogCard(icon: icon, title: title, value: value, tint: tint, progress: progress)
        }
        .buttonStyle(.plain)
    }
}

struct QuickLogNavLink<Destination: View>: View {
    let icon: String
    let title: String
    let value: String?
    let tint: Color
    var progress: Double? = nil
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination()) {
            QuickLogCard(icon: icon, title: title, value: value, tint: tint, progress: progress)
        }
        .buttonStyle(.plain)
    }
}
