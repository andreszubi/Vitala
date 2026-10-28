import SwiftUI

/// Full-screen guided breathing. Presented with `fullScreenCover`.
struct SessionPlayerView: View {
    let session: MindfulnessSession
    /// Called with the saved session when the user chooses to write about it.
    var onJournal: ((LoggedMindfulness) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AmbientSoundPlayer.Sound.storageKey) private var soundChoice: String = AmbientSoundPlayer.Sound.defaultSound.rawValue
    @State private var ambient = AmbientSoundPlayer()

    @State private var startedAt: Date = .now
    /// Wall-clock bookkeeping so timing stays right if the app is backgrounded.
    @State private var accumulated: TimeInterval = 0
    @State private var runningSince: Date? = .now
    @State private var now: Date = .now
    @State private var lastStepIndex: Int = -1
    @State private var confirmingEnd = false
    @State private var finished = false
    /// Set once a session is saved; shows the completion screen.
    @State private var saved: LoggedMindfulness? = nil

    private var pattern: [MindfulnessSession.BreathStep] { session.category.pattern }
    private var cycleLength: Int { pattern.reduce(0) { $0 + $1.seconds } }
    private var totalSeconds: Int { session.minutes * 60 }
    private var isPlaying: Bool { runningSince != nil }

    private var elapsedPrecise: TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }
    private var elapsed: Int { Int(elapsedPrecise) }
    private var progress: Double { min(1, elapsedPrecise / Double(max(totalSeconds, 1))) }

    /// Where we are in the breathing cycle.
    private var position: (index: Int, remaining: Int) {
        var t = elapsed % max(cycleLength, 1)
        for (i, step) in pattern.enumerated() {
            if t < step.seconds { return (i, step.seconds - t) }
            t -= step.seconds
        }
        return (0, pattern.first?.seconds ?? 4)
    }
    private var step: MindfulnessSession.BreathStep { pattern[position.index] }
    private var prompt: String {
        let prompts = session.category.prompts
        return prompts[(elapsed / 30) % prompts.count]
    }

    private var sound: AmbientSoundPlayer.Sound {
        AmbientSoundPlayer.Sound(rawValue: soundChoice) ?? .defaultSound
    }

    private var expanded: Bool {
        switch step.kind {
        case .inhale: true
        case .hold: position.index > 0 && pattern[position.index - 1].kind == .inhale
        case .exhale: false
        }
    }

    var body: some View {
        let tint = Color(hex: session.tint)
        ZStack {
            SessionBackground(category: session.category, tint: tint)
                .equatable()

            if let saved {
                completion(saved)
                    .transition(.opacity)
            } else {
                player
            }
        }
        .animation(.easeInOut(duration: 0.3), value: saved != nil)
        .preferredColorScheme(.dark)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            // Every session starts on the default sound; a change made from
            // the menu lasts for that session only.
            soundChoice = AmbientSoundPlayer.Sound.defaultSound.rawValue
            ambient.play(sound, for: session.category)
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            ambient.stop()
        }
        .onChange(of: soundChoice) { _, _ in
            ambient.play(sound, for: session.category)
            if !isPlaying { ambient.pause() }
        }
        .onChange(of: expanded) { _, isExpanded in ambient.setBreath(expanded: isExpanded) }
        .onChange(of: scenePhase) { _, phase in
            // The audio engine stops in the background; restart it on return.
            if phase == .active && isPlaying && !finished { ambient.play(sound, for: session.category) }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                tick()
            }
        }
        .confirmationDialog("End session?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            if elapsed >= 60 {
                Button("Save \(loggedMinutes) min") { save() }
            }
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep breathing", role: .cancel) {}
        } message: {
            Text(elapsed >= 60 ? "Nice work." : "Sessions shorter than a minute aren't saved.")
        }
    }

    // MARK: Sections

    private var player: some View {
        VStack(spacing: VitalaSpacing.lg) {
            topBar
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text(session.title)
                    .font(VitalaFont.title(24))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text(session.subtitle)
                    .font(VitalaFont.body(15))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .multilineTextAlignment(.center)
            .readableOnScene()

            breathingCircle

            Text(prompt)
                .font(VitalaFont.body(16))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VitalaSpacing.lg)
                .frame(minHeight: 48)
                .id(prompt)
                .transition(.opacity)
                .readableOnScene()

            if sound.usesBinaural {
                Label("Binaural tones work best with headphones", systemImage: "headphones")
                    .font(VitalaFont.caption(12))
                    .foregroundStyle(.white.opacity(0.9))
                    .readableOnScene()
            }

            Spacer(minLength: 0)
            progressBar
            controls
                .padding(.bottom, VitalaSpacing.md)
        }
        .padding(.horizontal, VitalaSpacing.lg)
    }

    private func completion(_ entry: LoggedMindfulness) -> some View {
        VStack(spacing: VitalaSpacing.lg) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Session saved")
                    .font(VitalaFont.title(28))
                    .accessibilityAddTraits(.isHeader)
                Text("\(entry.minutes) min of \(entry.title). Take a moment to note how you feel.")
                    .font(VitalaFont.body(16))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .readableOnScene()
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                if let onJournal {
                    Button {
                        dismiss()
                        onJournal(entry)
                    } label: {
                        Label("Write in journal", systemImage: "book.closed.fill")
                            .font(VitalaFont.bodyMedium(17))
                            .foregroundStyle(Color(hex: session.tint))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Capsule().fill(.white))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                Button { dismiss() } label: {
                    Text("Done")
                        .font(VitalaFont.bodyMedium(17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(.white.opacity(0.2)))
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle())
            }
            .padding(.bottom, VitalaSpacing.md)
        }
        .padding(.horizontal, VitalaSpacing.lg)
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "xmark", label: "End session", foreground: .white) { endTapped() }
            Spacer()
            Text(session.category.label)
                .font(VitalaFont.caption())
                .foregroundStyle(.white.opacity(0.9))
                .readableOnScene()
            Spacer()
            HStack(spacing: 8) {
                // `.equatable()` keeps the countdown's four updates a second
                // from reaching the menus; they redraw only when their own
                // saved choice changes. Without it an open menu was rebuilt
                // mid-tap, dropping taps and making UIKit log "Decomposition
                // of 'bounds' was requested…".
                SceneMenuButton().equatable()
                SoundMenuButton().equatable()
            }
        }
        .padding(.top, VitalaSpacing.xs)
    }

    private var breathingCircle: some View {
        let duration = Double(step.seconds)
        // Only the circles breathe slowly; the label and count switch promptly
        // so they stay in step with each second.
        let breath: Animation = reduceMotion ? .easeInOut(duration: 0.3) : .easeInOut(duration: duration)
        return ZStack {
            Group {
                Circle().fill(.white.opacity(0.14)).frame(width: 260, height: 260)
                    .scaleEffect(reduceMotion ? 1 : (expanded ? 1.12 : 0.86))
                Circle().fill(.white.opacity(expanded ? 0.28 : 0.18)).frame(width: 190, height: 190)
                    .scaleEffect(reduceMotion ? 1 : (expanded ? 1.12 : 0.86))
            }
            .animation(breath, value: expanded)
            VStack(spacing: 4) {
                Text(step.label)
                    .font(VitalaFont.title(26))
                    .foregroundStyle(.white)
                    .id(step.label)
                    .transition(.opacity)
                Text("\(position.remaining)")
                    .numeralFont(52)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
            }
            .animation(.easeOut(duration: 0.2), value: step.label)
            .animation(.easeOut(duration: 0.2), value: position.remaining)
            .readableOnScene()
        }
        .frame(height: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.label)
        .accessibilityValue("\(position.remaining) seconds")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            HStack {
                Text(timeString(elapsed))
                Spacer()
                Text(timeString(totalSeconds))
            }
            .font(VitalaFont.caption(12))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.9))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session progress")
        .accessibilityValue("\(elapsed / 60) of \(session.minutes) minutes")
    }

    private var controls: some View {
        HStack(spacing: 28) {
            GlassIconButton(systemName: "arrow.counterclockwise", label: "Restart", size: 60, foreground: .white) { restart() }
            GlassIconButton(systemName: isPlaying ? "pause.fill" : "play.fill",
                            label: isPlaying ? "Pause" : "Resume", size: 84, foreground: .white) { togglePlay() }
            GlassIconButton(systemName: "checkmark", label: "Finish", size: 60, foreground: .white) { endTapped() }
        }
        .glassGroup(spacing: 28)
    }

    // MARK: Logic

    private var loggedMinutes: Int { max(1, Int((Double(elapsed) / 60).rounded())) }

    private func tick() {
        guard !finished else { return }
        now = .now
        let index = position.index
        if isPlaying && index != lastStepIndex {
            lastStepIndex = index
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            AccessibilityNotification.Announcement(step.label).post()
        }
        if elapsed >= totalSeconds { save() }
    }

    private func togglePlay() {
        let t = Date.now
        if let since = runningSince {
            accumulated += t.timeIntervalSince(since)
            runningSince = nil
            ambient.pause()
        } else {
            runningSince = t
            ambient.resume()
        }
        now = t
    }

    private func restart() {
        accumulated = 0
        runningSince = .now
        startedAt = .now
        lastStepIndex = -1
        now = .now
    }

    private func endTapped() {
        if elapsed >= totalSeconds { save() } else { confirmingEnd = true }
    }

    private func save() {
        guard !finished else { return }
        finished = true
        guard elapsed >= 60 else { dismiss(); return }
        let entry = LoggedMindfulness(sessionId: session.id, title: session.title,
                                      minutes: min(loggedMinutes, session.minutes), completedAt: .now)
        Task {
            try? await DataStore.shared.logMindfulness(entry)
            Haptics.success()
        }
        ambient.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        saved = entry
    }

    private func timeString(_ secs: Int) -> String {
        String(format: "%02d:%02d", secs / 60, secs % 60)
    }
}

/// The sound picker in the player's top bar. It has no inputs, so it is
/// always equal to its previous self; see `topBar` for why that matters.
private struct SoundMenuButton: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { true }

    @AppStorage(AmbientSoundPlayer.Sound.storageKey) private var soundChoice: String = AmbientSoundPlayer.Sound.defaultSound.rawValue

    private var sound: AmbientSoundPlayer.Sound {
        AmbientSoundPlayer.Sound(rawValue: soundChoice) ?? .defaultSound
    }

    /// Glass buttons add their own padding on iOS 26+, so the label is smaller
    /// there to match the 44pt close button.
    private var labelSize: CGFloat {
        if #available(iOS 26.0, *) { return 28 }
        return 44
    }

    var body: some View {
        Menu {
            Picker("Sound", selection: $soundChoice) {
                ForEach(AmbientSoundPlayer.Sound.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: sound == .silent ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: labelSize, height: labelSize)
                .background {
                    if #unavailable(iOS 26.0) { Circle().fill(.white.opacity(0.2)) }
                }
                .contentShape(Circle())
        }
        .buttonBorderShape(.circle)
        .glassButtonStyle()
        .accessibilityLabel("Sound")
        .accessibilityValue(sound.label)
        // Never let an animation from the breathing guide drive the menu.
        .transaction { $0.animation = nil }
    }
}

/// The animated scene, read from storage so changing it from the menu
/// redraws only the background, never the countdown.
private struct SessionBackground: View, Equatable {
    let category: MindfulnessSession.Category
    let tint: Color

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.category == rhs.category && lhs.tint == rhs.tint
    }
    @AppStorage("vitala.sessionScene") private var sceneChoice: String = ZenScene.automatic.rawValue

    var body: some View {
        let choice = ZenScene(rawValue: sceneChoice) ?? .automatic
        ZenBackground(scene: choice.resolved(for: category), tint: tint)
    }
}

/// Picks the background scene. Kept out of the countdown's updates for the
/// same reason as `SoundMenuButton`.
private struct SceneMenuButton: View, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool { true }

    @AppStorage("vitala.sessionScene") private var sceneChoice: String = ZenScene.automatic.rawValue

    private var scene: ZenScene { ZenScene(rawValue: sceneChoice) ?? .automatic }

    private var labelSize: CGFloat {
        if #available(iOS 26.0, *) { return 28 }
        return 44
    }

    var body: some View {
        Menu {
            Picker("Scene", selection: $sceneChoice) {
                ForEach(ZenScene.allCases) { option in
                    Label(option.label, systemImage: option.icon).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: labelSize, height: labelSize)
                .background {
                    if #unavailable(iOS 26.0) { Circle().fill(.white.opacity(0.2)) }
                }
                .contentShape(Circle())
        }
        .buttonBorderShape(.circle)
        .glassButtonStyle()
        .accessibilityLabel("Scene")
        .accessibilityValue(scene.label)
        .transaction { $0.animation = nil }
    }
}

