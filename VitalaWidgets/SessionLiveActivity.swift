import ActivityKit
import SwiftUI
import WidgetKit

/// The Lock Screen banner and Dynamic Island for a workout or a breathing
/// session in progress.
struct SessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Palette(context.attributes.kind).base)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let palette = Palette(context.attributes.kind)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Guide(attributes: context.attributes, state: context.state, palette: palette, size: 52)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        ClockText(clock: context.state.clock)
                            .font(.title3.weight(.semibold).monospacedDigit())
                        Text(context.attributes.kind == .breathing ? "left" : "total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 80, alignment: .trailing)
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(context.attributes.name)
                            .font(.caption2)
                            .foregroundStyle(palette.accent)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Track(state: context.state, palette: palette)
                        .padding(.horizontal, 6)
                        .padding(.top, 4)
                }
            } compactLeading: {
                Guide(attributes: context.attributes, state: context.state, palette: palette, size: 22)
            } compactTrailing: {
                if let breath = context.state.breath {
                    Text(breath.word)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                } else {
                    ClockText(clock: context.state.clock)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .frame(maxWidth: 48)
                }
            } minimal: {
                Guide(attributes: context.attributes, state: context.state, palette: palette, size: 20)
            }
            .keylineTint(palette.accent)
        }
    }
}

/// Colours for the activity. The extension has no access to the app's
/// colour assets, so they are set here: night blue into teal for breathing,
/// deep green for workouts.
private struct Palette {
    let base: Color
    let top: Color
    let bottom: Color
    let accent: Color

    init(_ kind: SessionActivityAttributes.Kind) {
        switch kind {
        case .breathing:
            base = Color(red: 0.10, green: 0.14, blue: 0.29)
            top = Color(red: 0.13, green: 0.16, blue: 0.36)
            bottom = Color(red: 0.11, green: 0.33, blue: 0.36)
            accent = Color(red: 0.66, green: 0.90, blue: 0.86)
        case .workout:
            base = Color(red: 0.09, green: 0.21, blue: 0.17)
            top = Color(red: 0.10, green: 0.26, blue: 0.21)
            bottom = Color(red: 0.20, green: 0.42, blue: 0.33)
            accent = Color(red: 0.99, green: 0.82, blue: 0.60)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct LockScreenView: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState

    private var palette: Palette { Palette(attributes.kind) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Guide(attributes: attributes, state: state, palette: palette, size: 58)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.name.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                    Text(state.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .contentTransition(.opacity)
                    if !state.detail.isEmpty {
                        Text(state.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 1) {
                    ClockText(clock: state.clock)
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: 90, alignment: .trailing)
            }

            Track(state: state, palette: palette)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.gradient)
    }

    private var caption: String {
        if state.isFinished { return "done" }
        if state.isPaused { return "paused" }
        return attributes.kind == .breathing ? "left" : "total"
    }
}

/// The round guide on the left. For a breathing session it swells and
/// fills on the in-breath, stays full for a hold and empties on the
/// out-breath, with an arrow saying which. For a workout it carries the
/// workout's symbol, ringed by the time left in a timed exercise.
private struct Guide: View {
    let attributes: SessionActivityAttributes
    let state: SessionActivityAttributes.ContentState
    let palette: Palette
    let size: CGFloat

    private var lineWidth: CGFloat { max(2, size * 0.075) }

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.10))
            // The soft centre: large when the lungs are full, small when empty.
            Circle()
                .fill(palette.accent.opacity(0.28))
                .scaleEffect(innerScale)
            ring
            Image(systemName: symbol)
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var symbol: String {
        if state.isFinished { return "checkmark" }
        if state.isPaused { return "pause.fill" }
        return state.breath?.symbol ?? attributes.symbol
    }

    private var innerScale: CGFloat {
        guard let breath = state.breath else { return 0.62 }
        return breath.endsFull ? 0.86 : 0.5
    }

    @ViewBuilder
    private var ring: some View {
        if let step = state.step, step.end > step.start, state.breath != .holdFull, state.breath != .holdEmpty {
            // Fills as an in-breath or an exercise goes on; empties with an out-breath.
            ProgressView(timerInterval: step.start...step.end, countsDown: state.breath == .breatheOut) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.circular)
            .tint(palette.accent)
        } else {
            Circle()
                .trim(from: 0, to: state.breath == .holdEmpty ? 0.001 : (state.isPaused || state.step == nil ? 0 : 1))
                .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(lineWidth / 2)
        }
    }
}

/// The line along the bottom: how far through the breathing session, or
/// which exercise of the workout this is.
private struct Track: View {
    let state: SessionActivityAttributes.ContentState
    let palette: Palette

    var body: some View {
        if let whole = state.whole, whole.end > whole.start {
            ProgressView(timerInterval: whole.start...whole.end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(palette.accent)
            .accessibilityLabel("Session progress")
        } else if let position = state.position, let count = state.count, count > 0 {
            HStack(spacing: 4) {
                ForEach(0..<min(count, 16), id: \.self) { index in
                    Capsule()
                        .fill(index < position ? palette.accent : .white.opacity(0.22))
                        .frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Exercise \(position) of \(count)")
        } else {
            Capsule()
                .fill(state.isFinished ? palette.accent : .white.opacity(0.22))
                .frame(height: 5)
                .accessibilityHidden(true)
        }
    }
}

/// The activity's clock: ticking by itself while running, still otherwise.
private struct ClockText: View {
    let clock: SessionActivityAttributes.Clock

    var body: some View {
        switch clock {
        case .down(let end):
            Text(timerInterval: Date.now...max(end, .now), countsDown: true)
                .multilineTextAlignment(.trailing)
        case .up(let start):
            Text(timerInterval: min(start, .now)...Date.distantFuture, countsDown: false)
                .multilineTextAlignment(.trailing)
        case .stopped(let seconds):
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
    }
}
