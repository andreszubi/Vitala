import SwiftUI

/// Vitala's leaf mark, drawn as an original shape. (SF Symbols may not be
/// used as logos or app icons under their licence.) The app icon is rendered
/// from the same geometry.
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var body = Path()
        body.move(to: p(0.20, 0.80))
        body.addCurve(to: p(0.82, 0.18), control1: p(0.10, 0.38), control2: p(0.40, 0.12))
        body.addCurve(to: p(0.20, 0.80), control1: p(0.88, 0.60), control2: p(0.62, 0.90))
        body.closeSubpath()

        var stem = Path()
        stem.move(to: p(0.215, 0.785))
        stem.addLine(to: p(0.10, 0.90))
        return body.union(stem.strokedPath(StrokeStyle(lineWidth: rect.width * 0.045, lineCap: .round)))
    }
}

/// The centre vein, cut out of the leaf.
struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: p(0.30, 0.70))
        path.addQuadCurve(to: p(0.70, 0.30), control: p(0.44, 0.48))
        return path.strokedPath(StrokeStyle(lineWidth: rect.width * 0.035, lineCap: .round))
    }
}

/// Leaf mark on a gradient disc.
struct BrandMark: View {
    var size: CGFloat = 110

    var body: some View {
        ZStack {
            Circle().fill(VitalaColor.primaryGradient)
            LeafShape()
                .fill(.white)
                .padding(size * 0.2)
            LeafVeinShape()
                .fill(VitalaColor.primaryFill)
                .padding(size * 0.2)
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
