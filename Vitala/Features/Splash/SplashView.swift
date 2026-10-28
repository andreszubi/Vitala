import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                BrandMark(size: 110)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
                    .shadow(color: VitalaColor.primaryFill.opacity(0.3), radius: 18, y: 8)
                Text("Vitala")
                    .font(VitalaFont.display(44))
                    .foregroundStyle(VitalaColor.primary)
                Text("Healthy living, gently.")
                    .font(VitalaFont.body(16))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
            .opacity(appeared ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vitala. Healthy living, gently.")
        }
        .task {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.45)) { appeared = true }
            try? await Task.sleep(for: .milliseconds(700))
            onFinish()
        }
    }
}

#Preview { SplashView(onFinish: {}) }
