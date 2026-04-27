import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            VitalaColor.creamGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(VitalaColor.primaryGradient)
                        .frame(width: 110, height: 110)
                        .scaleEffect(pulse ? 1.06 : 1)
                        .shadow(color: VitalaColor.primary.opacity(0.35), radius: 18, y: 8)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("Vitala")
                    .font(VitalaFont.display(44))
                    .foregroundStyle(VitalaColor.primary)
                Text("Healthy living, gently.")
                    .font(VitalaFont.body(16))
                    .foregroundStyle(VitalaColor.textSecondary)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                onFinish()
            }
        }
    }
}

#Preview { SplashView(onFinish: {}) }
