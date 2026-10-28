import SwiftUI

/// Animated multi-ring progress, similar to Apple's Activity rings.
/// Decorative to VoiceOver — callers describe the values in text.
struct ActivityRings: View {
    let move: Double          // 0...1
    let exercise: Double      // 0...1
    let stand: Double         // 0...1
    var lineWidth: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ring(progress: move,     color: VitalaColor.ringMove,     diameter: 1.0)
            ring(progress: exercise, color: VitalaColor.ringExercise, diameter: 0.74)
            ring(progress: stand,    color: VitalaColor.ringStand,    diameter: 0.48)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func ring(progress: Double, color: Color, diameter: CGFloat) -> some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * diameter
            ZStack {
                Circle()
                    .stroke(color.opacity(0.18), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.001, min(progress, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: progress)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Single-value progress ring with center label.
struct ProgressRingSingle: View {
    let progress: Double
    let title: String
    let value: String
    var color: Color = VitalaColor.primary
    var lineWidth: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            // Keep the centre label clear of the stroke at any ring size.
            let inset = max(geo.size.width, 1) * 0.2

            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0.001, min(progress, 1)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: progress)

                // The ring is a fixed size, so its label shrinks to fit rather
                // than overflow; VoiceOver and the surrounding text carry the
                // full-size value.
                VStack(spacing: 2) {
                    Text(value)
                        .font(VitalaFont.title(26))
                        .foregroundStyle(VitalaColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(title)
                        .font(VitalaFont.caption())
                        .foregroundStyle(VitalaColor.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, inset)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value), \(Int((min(max(progress, 0), 1) * 100).rounded())) percent")
    }
}

#Preview {
    HStack {
        ActivityRings(move: 0.7, exercise: 0.4, stand: 0.9).frame(width: 180)
        ProgressRingSingle(progress: 0.66, title: "Steps", value: "6,234").frame(width: 160)
    }
    .padding()
    .background(VitalaColor.background)
}
