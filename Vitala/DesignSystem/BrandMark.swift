import SwiftUI

/// Vitala's sprout mark, drawn as original shapes. (SF Symbols may not be
/// used as logos or app icons under their licence.) Coordinates match the
/// layers in AppIcon.icon, on a 1024-point canvas.
struct SproutLeafShape: Shape {
    enum Leaf { case front, back }
    let leaf: Leaf

    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 1024 * rect.width, y: rect.minY + y / 1024 * rect.height)
        }
        var path = Path()
        switch leaf {
        case .front:
            path.move(to: p(505, 690))
            path.addCurve(to: p(770, 215), control1: p(684, 715.1), control2: p(835.7, 426))
            path.addCurve(to: p(505, 690), control1: p(578.5, 282.5), control2: p(413.3, 564.1))
        case .back:
            path.move(to: p(495, 700))
            path.addCurve(to: p(225, 430), control1: p(381.6, 748.6), control2: p(223.7, 582.5))
            path.addCurve(to: p(495, 700), control1: p(362.2, 444), control2: p(527.4, 602.8))
        }
        path.closeSubpath()
        return path
    }
}

struct SproutStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 1024 * rect.width, y: rect.minY + y / 1024 * rect.height)
        }
        var path = Path()
        path.move(to: p(500, 690))
        path.addCurve(to: p(478, 850), control1: p(500, 760), control2: p(492, 800))
        return path.strokedPath(StrokeStyle(lineWidth: rect.width * 40 / 1024, lineCap: .round))
    }
}

/// Sprout mark on a gradient disc, echoing the app icon's frosted layers.
struct BrandMark: View {
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            Circle().fill(VitalaColor.primaryGradient)
            Group {
                SproutStemShape().fill(.white.opacity(0.7))
                SproutLeafShape(leaf: .back).fill(.white.opacity(0.65))
                SproutLeafShape(leaf: .front)
                    .fill(LinearGradient(colors: [.white, .white.opacity(0.88)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.15), radius: size * 0.02, y: size * 0.01)
            }
            .padding(size * 0.06)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        BrandMark(size: 110)
        BrandMark(size: 56)
    }
    .padding()
    .background(VitalaColor.background)
}
