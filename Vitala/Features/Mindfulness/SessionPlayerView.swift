import SwiftUI

struct SessionPlayerView: View {
    let session: MindfulnessSession
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var health: HealthKitService

    @State private var elapsed: Int = 0
    @State private var isPlaying = true
    @State private var phase: BreathPhase = .inhale
    @State private var phaseElapsed: Int = 0
    @State private var startedAt: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum BreathPhase: Int, CaseIterable {
        case inhale, holdIn, exhale, holdOut
        var seconds: Int { 4 }
        var label: String {
            switch self {
            case .inhale: "Inhale"
            case .holdIn: "Hold"
            case .exhale: "Exhale"
            case .holdOut: "Hold"
            }
        }
    }

    private var totalSeconds: Int { session.minutes * 60 }
    private var progress: Double { Double(elapsed) / Double(totalSeconds) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: session.tint),
                                    Color(hex: session.tint).opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: VitalaSpacing.lg) {
                topBar
                Spacer()
                Text(session.title).font(VitalaFont.title(24)).foregroundStyle(.white.opacity(0.95))
                Text(session.subtitle).font(VitalaFont.body(15)).foregroundStyle(.white.opacity(0.8))

                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 280, height: 280)
                        .scaleEffect(scaleForPhase)
                        .animation(.easeInOut(duration: Double(phase.seconds)), value: phase)
                    Circle().fill(.white.opacity(0.25)).frame(width: 200, height: 200)
                        .scaleEffect(scaleForPhase)
                        .animation(.easeInOut(duration: Double(phase.seconds)), value: phase)
                    VStack(spacing: 4) {
                        Text(phase.label)
                            .font(VitalaFont.title(28))
                            .foregroundStyle(.white)
                        Text("\(phase.seconds - phaseElapsed)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    ProgressView(value: progress)
                        .tint(.white)
                        .background(.white.opacity(0.25))
                        .clipShape(Capsule())
                        .frame(height: 4)
                    HStack {
                        Text(timeString(elapsed)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(timeString(totalSeconds)).foregroundStyle(.white.opacity(0.8))
                    }
                    .font(VitalaFont.caption(12))
                }

                HStack(spacing: 24) {
                    Button { restart() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 22))
                            .frame(width: 56, height: 56)
                            .background(.white.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    Button { isPlaying.toggle() } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30))
                            .frame(width: 80, height: 80)
                            .background(.white)
                            .foregroundStyle(Color(hex: session.tint))
                            .clipShape(Circle())
                    }
                    Button { finish() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22))
                            .frame(width: 56, height: 56)
                            .background(.white.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, VitalaSpacing.lg)
            }
            .padding(.horizontal, VitalaSpacing.lg)
        }
        .navigationBarBackButtonHidden()
        .onReceive(timer) { _ in tick() }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Now playing").font(VitalaFont.caption()).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, VitalaSpacing.md)
    }

    private var scaleForPhase: CGFloat {
        switch phase {
        case .inhale, .holdIn: return 1.18
        case .exhale, .holdOut: return 0.9
        }
    }

    private func tick() {
        guard isPlaying else { return }
        elapsed += 1
        phaseElapsed += 1
        if phaseElapsed >= phase.seconds {
            phaseElapsed = 0
            let next = (phase.rawValue + 1) % BreathPhase.allCases.count
            phase = BreathPhase(rawValue: next) ?? .inhale
        }
        if elapsed >= totalSeconds {
            finish()
        }
    }

    private func restart() {
        elapsed = 0; phaseElapsed = 0; phase = .inhale; startedAt = .now
    }

    private func finish() {
        let endedAt = Date.now
        let entry = LoggedMindfulness(sessionId: session.id, title: session.title,
                                      minutes: max(1, elapsed / 60), completedAt: endedAt)
        Task {
            try? await FirestoreService.shared.logMindfulness(entry)
        }
        // Fire-and-forget HK write so dismiss isn't blocked.
        Task.detached { [health, startedAt, endedAt] in
            try? await health.logMindfulness(start: startedAt, end: endedAt)
        }
        dismiss()
    }

    private func timeString(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }
}
